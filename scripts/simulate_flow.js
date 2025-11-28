const {S3Client, PutObjectCommand, ListBucketsCommand} = require("@aws-sdk/client-s3");
const axios = require("axios");

// Configuration
const SALESFORCE_URL = "http://localhost:3001/services/data/v50.0/query?q=SELECT+Id,Name+FROM+Account";
const S3_ENDPOINT = "http://localhost:4566";
const REGION = "us-east-1";

const s3 = new S3Client({
    endpoint: S3_ENDPOINT,
    region: REGION,
    credentials: {
        accessKeyId: "test",
        secretAccessKey: "test"
    },
    forcePathStyle: true // Needed for LocalStack
});

async function run() {
    try {
        // 1. Fetch data from Mock Salesforce
        console.log("Fetching data from Mock Salesforce...");
        const sfResponse = await axios.get(SALESFORCE_URL);
        const data = JSON.stringify(sfResponse.data);
        console.log("Data received:", data);

        // 2. Find the S3 bucket
        console.log("Finding S3 bucket...");
        const {Buckets} = await s3.send(new ListBucketsCommand({}));
        const bucket = Buckets.find(b => b.Name.startsWith("boomi-local-data-"));

        if (!bucket) {
            console.error("No bucket found starting with 'boomi-local-data-'");
            console.log("Available buckets:", Buckets.map(b => b.Name));
            return;
        }
        console.log(`Found bucket: ${bucket.Name}`);

        // 3. Upload to S3
        const key = `salesforce-data-${Date.now()}.json`;
        console.log(`Uploading to s3://${bucket.Name}/${key}...`);

        await s3.send(new PutObjectCommand({
            Bucket: bucket.Name,
            Key: key,
            Body: data
        }));

        console.log("Upload complete! This should trigger the Step Function.");

    } catch (error) {
        console.error("Error:", error.message);
        if (error.response) {
            console.error("Response data:", error.response.data);
        }
    }
}

run();
