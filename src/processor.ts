import {S3Client, GetObjectCommand} from "@aws-sdk/client-s3";
import {Readable} from "stream";
import axios from "axios";

const s3Client = new S3Client({});

interface S3EventDetail {
    bucket: {
        name: string;
    };
    object: {
        key: string;
    };
}

interface EventBridgeEvent {
    detail: S3EventDetail;
}

export const handler = async (event: EventBridgeEvent): Promise<any> => {
    console.log("Received event:", JSON.stringify(event, null, 2));

    try {
        const bucketName = event.detail.bucket.name;
        const objectKey = event.detail.object.key;

        console.log(`Processing file: s3://${bucketName}/${objectKey}`);

        // 1. Get file from S3
        const getObjectParams = {
            Bucket: bucketName,
            Key: objectKey,
        };
        const command = new GetObjectCommand(getObjectParams);
        const response = await s3Client.send(command);

        if (!response.Body) {
            throw new Error("S3 object body is empty");
        }

        // Convert stream to string
        const fileContent = await streamToString(response.Body as Readable);
        console.log("File content retrieved. Length:", fileContent.length);

        // 2. POST to External API
        const apiUrl = process.env.EXTERNAL_API_URL;
        if (!apiUrl) {
            throw new Error("EXTERNAL_API_URL environment variable is not set");
        }

        console.log(`Posting data to ${apiUrl}`);
        const apiResponse = await axios.post(apiUrl, {
            data: fileContent, // Adjust payload structure as needed
            source: "salesforce-appflow",
            filename: objectKey
        });

        console.log("API Response status:", apiResponse.status);

        return {
            statusCode: 200,
            body: JSON.stringify({message: "Success", apiStatus: apiResponse.status}),
        };

    } catch (error: any) {
        console.error("Error processing file:", error);
        throw error; // Rethrow to fail the Step Function execution
    }
};

// Helper to convert stream to string
const streamToString = (stream: Readable): Promise<string> => {
    return new Promise((resolve, reject) => {
        const chunks: Buffer[] = [];
        stream.on("data", (chunk) => chunks.push(Buffer.from(chunk)));
        stream.on("error", (err) => reject(err));
        stream.on("end", () => resolve(Buffer.concat(chunks).toString("utf-8")));
    });
};
