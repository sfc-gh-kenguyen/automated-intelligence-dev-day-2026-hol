package com.snowflake.demo;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.*;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Properties;

public class ConfigManager {
    private static final Logger logger = LoggerFactory.getLogger(ConfigManager.class);
    private final Properties properties;
    private final JsonNode profileConfig;

    public ConfigManager(String propertiesPath, String profilePath) throws IOException {
        this.properties = loadProperties(propertiesPath);
        this.profileConfig = loadProfile(profilePath);
    }

    private Properties loadProperties(String path) throws IOException {
        Properties props = new Properties();
        try (InputStream input = new FileInputStream(path)) {
            props.load(input);
            logger.info("Loaded configuration from: {}", path);
        }
        return props;
    }

    private JsonNode loadProfile(String path) throws IOException {
        ObjectMapper mapper = new ObjectMapper();
        String content = new String(Files.readAllBytes(Path.of(path)));
        logger.info("Loaded Snowflake profile from: {}", path);
        return mapper.readTree(content);
    }

    public String getProperty(String key) {
        return properties.getProperty(key);
    }

    public String getProperty(String key, String defaultValue) {
        return properties.getProperty(key, defaultValue);
    }

    public int getIntProperty(String key, int defaultValue) {
        String value = properties.getProperty(key);
        return value != null ? Integer.parseInt(value) : defaultValue;
    }

    public String getSnowflakeUser() {
        return profileConfig.get("user").asText();
    }

    public String getSnowflakeAccount() {
        return profileConfig.get("account").asText();
    }

    public String getSnowflakeUrl() {
        return profileConfig.get("url").asText();
    }

    public String getPrivateKey() {
        return profileConfig.get("private_key").asText();
    }

    public String getDatabase() {
        return profileConfig.get("database").asText();
    }

    public String getSchema() {
        return profileConfig.get("schema").asText();
    }

    public String getWarehouse() {
        return profileConfig.get("warehouse").asText();
    }

    public String getRole() {
        JsonNode roleNode = profileConfig.get("role");
        return roleNode != null ? roleNode.asText() : "AUTOMATED_INTELLIGENCE";
    }
}
