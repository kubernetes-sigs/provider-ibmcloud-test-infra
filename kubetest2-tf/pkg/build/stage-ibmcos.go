package build

import (
	"bufio"
	"errors"
	"fmt"
	"os"
	"regexp"
	"strings"

	"github.com/IBM/ibm-cos-sdk-go/aws"
	"github.com/IBM/ibm-cos-sdk-go/aws/credentials"
	"github.com/IBM/ibm-cos-sdk-go/aws/session"
	"github.com/IBM/ibm-cos-sdk-go/service/s3"
	"github.com/IBM/ibm-cos-sdk-go/service/s3/s3manager"

	"k8s.io/klog/v2"
)

type IBMCOSStager struct {
	StageLocation   string
	RepoRoot        string
	Region          string
	Bucket          string
	Path            string
	TargetBuildArch string
	Credentials     *credentials.Credentials
}

// String implements fmt.Stringer so that any accidental log of an IBMCOSStager
// value never prints the embedded Credentials field.
func (i IBMCOSStager) String() string {
	return fmt.Sprintf("{StageLocation:%s Region:%s Bucket:%s Path:%s TargetBuildArch:%s Credentials:<redacted>}",
		i.StageLocation, i.Region, i.Bucket, i.Path, i.TargetBuildArch)
}

// GoString implements fmt.GoStringer (%#v verb) with the same redaction.
func (i IBMCOSStager) GoString() string {
	return i.String()
}

func NewIBMCOSStager(stageLocation, repoRoot, targetBuildArch, cosCredType string) (*IBMCOSStager, error) {
	re := regexp.MustCompile(`^([a-zA-Z]+):\/\/([a-zA-Z0-9-]+)\/([a-zA-Z0-9-]+)(\/.*)?$`)
	matches := re.FindStringSubmatch(stageLocation)
	if len(matches) < 3 {
		return nil, fmt.Errorf("invalid IBM COS stagelocation, missing region, bucket information, expected format is cos://us/bucket123/<PATH>")
	}

	var cred *credentials.Credentials

	switch cosCredType {
	case "shared":
		cred = credentials.NewSharedCredentials("", "")
	case "cos_hmac":
		cred = NewCosHmacCredentials("")
	default:
		return nil, errors.New("invalid credential type: " + cosCredType)
	}

	return &IBMCOSStager{
		StageLocation:   stageLocation,
		RepoRoot:        repoRoot,
		Region:          matches[2],
		Bucket:          matches[3],
		Path:            matches[4],
		TargetBuildArch: targetBuildArch,
		Credentials:     cred,
	}, nil
}

var _ Stager = &IBMCOSStager{}

func (i *IBMCOSStager) getS3Client() *s3.S3 {
	conf := aws.NewConfig().
		WithRegion(fmt.Sprintf("%s-standard", i.Region)).
		WithEndpoint(fmt.Sprintf("https://s3.%s.cloud-object-storage.appdomain.cloud", i.Region)).
		WithCredentials(i.Credentials).
		WithS3ForcePathStyle(true)

	sess := session.Must(session.NewSession())
	return s3.New(sess, conf)
}

// Stage implements Stager.
func (i *IBMCOSStager) Stage(version string) error {
	client := i.getS3Client()
	tgzFile := "kubernetes-server-" + strings.ReplaceAll(i.TargetBuildArch, "/", "-") + ".tar.gz"
	destinationKey := aws.String(i.Path + "/" + version + "/" + tgzFile)
	klog.V(1).Infof("uploading %s to %s/%s", tgzFile, i.StageLocation, version)

	f, err := os.Open(i.RepoRoot + "/_output/release-tars/" + tgzFile)
	if err != nil {
		return fmt.Errorf("failed to open artifact %s: %v", tgzFile, err)
	}
	defer f.Close()

	uploader := s3manager.NewUploaderWithClient(client)
	upParams := &s3manager.UploadInput{
		Bucket: aws.String(i.Bucket),
		Key:    destinationKey,
		Body:   aws.ReadSeekCloser(bufio.NewReader(f)),
	}
	if _, err = uploader.Upload(upParams); err != nil {
		return fmt.Errorf("failed to upload %s: %v", tgzFile, err)
	}
	klog.V(1).Infof("uploaded %s successfully", tgzFile)
	return nil
}
