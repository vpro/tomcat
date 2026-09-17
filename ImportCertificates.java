import java.io.BufferedReader;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyStore;
import java.security.cert.Certificate;
import java.security.cert.CertificateFactory;

void main(String[] args) throws Exception {
    if (args.length != 2) {
        throw new IllegalArgumentException("Usage: ImportCertificates <aliases-file> <cacerts-password>");
    }

    char[] password = args[1].toCharArray();
    Path cacerts = Path.of(System.getProperty("java.home"), "lib", "security", "cacerts");
    KeyStore keyStore = KeyStore.getInstance(cacerts.toFile(), password);
    CertificateFactory certificateFactory = CertificateFactory.getInstance("X.509");

    try (BufferedReader aliases = Files.newBufferedReader(Path.of(args[0]), StandardCharsets.UTF_8)) {
        String entry;
        while ((entry = aliases.readLine()) != null) {
            String[] fields = entry.split("\t", 2);
            if (fields.length != 2) {
                throw new IllegalArgumentException("Invalid certificate alias entry: " + entry);
            }

            Path certificateFile = Path.of(fields[0]);
            System.out.println("Importing " + certificateFile + " as " + fields[1]);
            try (InputStream certificateInput = Files.newInputStream(certificateFile)) {
                Certificate certificate = certificateFactory.generateCertificate(certificateInput);
                keyStore.setCertificateEntry(fields[1], certificate);
            }
        }
    }

    try (var output = Files.newOutputStream(cacerts)) {
        keyStore.store(output, password);
    }
}
