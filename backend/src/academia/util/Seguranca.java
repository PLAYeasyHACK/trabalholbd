package academia.util;

import java.math.BigInteger;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

public final class Seguranca {
    private Seguranca() {}

    public static String hash(String texto) {
        if (texto == null || texto.isEmpty()) throw new IllegalArgumentException("Informe a senha.");
        try {
            byte[] d = MessageDigest.getInstance("SHA-256").digest(texto.getBytes(StandardCharsets.UTF_8));
            return String.format("%064x", new BigInteger(1, d));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
