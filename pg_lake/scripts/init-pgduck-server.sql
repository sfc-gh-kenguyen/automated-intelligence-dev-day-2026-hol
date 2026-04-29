-- Drop any cached secrets and recreate with credential_chain
DROP SECRET IF EXISTS s3default;
DROP SECRET IF EXISTS s3_aws_secret;
DROP SECRET IF EXISTS gcsdefault;

-- Create AWS secret for S3 access using credential_chain (reads from ~/.aws/credentials)
CREATE SECRET s3_aws_secret(
    TYPE s3,
    PROVIDER credential_chain,
    REGION 'us-west-2'
);
