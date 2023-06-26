package dev.karambol;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.S3Event;
import com.amazonaws.services.lambda.runtime.events.models.s3.S3EventNotification.S3EventNotificationRecord;
import org.openapitools.openapidiff.core.OpenApiCompare;
import org.openapitools.openapidiff.core.model.ChangedOpenApi;
import org.openapitools.openapidiff.core.output.HtmlRender;
import org.openapitools.openapidiff.core.output.MarkdownRender;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import software.amazon.awssdk.awscore.exception.AwsServiceException;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.ListObjectVersionsRequest;
import software.amazon.awssdk.services.s3.model.ObjectVersion;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.utils.IoUtils;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.Comparator;
import java.util.HashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

// Handler value: example.Handler
public class Handler implements RequestHandler<S3Event, String> {
    private static final Logger logger = LoggerFactory.getLogger(Handler.class);
    private final String REGEX = ".*\\.([^\\.]*)";

    @Override
    public String handleRequest(S3Event s3event, Context context) {
        try {
            S3EventNotificationRecord record = s3event.getRecords().get(0);

            String srcBucket = record.getS3().getBucket().getName();

            // Object key may have spaces or unicode non-ASCII characters.
            String srcKey = record.getS3().getObject().getUrlDecodedKey();
            if (srcKey.contains("cpy-")) {
                logger.info("Avoiding recursion: " + srcKey);
                return "";
            }

            String dstBucket = srcBucket;
            String dstKey = "cpy-diff.html";

            // Infer the yaml type.
            Matcher matcher = Pattern.compile(REGEX).matcher(srcKey);
            if (!matcher.matches()) {
                logger.info("Unable to infer yaml type for key " + srcKey);
                return "";
            }

            // Download the yaml from S3 into a stream
            S3Client s3Client = S3Client.builder().build();
            InputStream s3Object = getObject(s3Client, srcBucket, srcKey, null);

            // Read the source yaml into dest yaml // TODO for now
            var prev = getObjectPrevVer(s3Client, srcBucket, srcKey);
            if (prev == null) {
                logger.info("no prev version for {}", srcKey);
                return "";
            }

            String spec = new String(s3Object.readAllBytes(), StandardCharsets.UTF_8);
            String prevSpec = new String(prev.readAllBytes(), StandardCharsets.UTF_8);
            final var diff = OpenApiCompare.fromContents(spec, prevSpec);

            // html
            String html = new HtmlRender("Changelog",
                    "https://dejano-with-tie-oapi-diff.s3.eu-central-1.amazonaws.com/diff.css")
                    .render(diff);
            var ba = new ByteArrayInputStream(html.getBytes());
            ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
            IoUtils.copy(ba, outputStream);
            putObject(s3Client, outputStream, dstBucket, dstKey);

            // md
            String md = new MarkdownRender().render(diff);
            var ba1 = new ByteArrayInputStream(md.getBytes());
            ByteArrayOutputStream outputStream1 = new ByteArrayOutputStream();
            IoUtils.copy(ba1, outputStream1);
            putObject(s3Client, outputStream1, dstBucket, dstKey + ".md");

            logger.info("Successfully duffed " + srcBucket + "/"
                    + srcKey + " and uploaded to " + dstBucket + "/" + dstKey);
            return "Ok";
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }

    private InputStream getObject(S3Client s3Client, String bucket, String key, String ver) {
        var getObjectRequest = GetObjectRequest.builder()
                .bucket(bucket)
                .key(key);
        if (ver != null) {
            getObjectRequest.versionId(ver);
        }
        return s3Client.getObject(getObjectRequest.build());
    }

    private InputStream getObjectPrevVer(S3Client s3Client, String bucket, String key) {
        final var listObjectVersionsResponse = s3Client.listObjectVersions(ListObjectVersionsRequest.builder()
                .bucket(bucket)
                .prefix(key)
                .maxKeys(2)
                .build());
        final var vers = listObjectVersionsResponse.versions().stream()
                .sorted(Comparator.comparingInt(v -> v.lastModified().getNano()))
                .toList();
        if (vers.size() > 1) {
            final var objectVersion = vers.get(1);
            return getObject(s3Client, bucket, key, objectVersion.versionId());
        }
        return null;
    }

    private void putObject(S3Client s3Client, ByteArrayOutputStream outputStream, String bucket, String key) {
        Map<String, String> metadata = new HashMap<>();
        metadata.put("Content-Length", Integer.toString(outputStream.size()));
        metadata.put("Content-type", "text/html");

        PutObjectRequest putObjectRequest = PutObjectRequest.builder()
                .bucket(bucket)
                .key(key)
                .contentType("text/html")
                .metadata(metadata)
                .build();

        // Uploading to S3 destination bucket
        logger.info("Writing to: " + bucket + "/" + key);
        try {
            s3Client.putObject(putObjectRequest,
                    RequestBody.fromBytes(outputStream.toByteArray()));
        } catch (AwsServiceException e) {
            logger.error(e.awsErrorDetails().errorMessage());
            System.exit(1);
        }
    }
}
