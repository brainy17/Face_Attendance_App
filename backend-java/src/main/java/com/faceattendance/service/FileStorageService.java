package com.faceattendance.service;

import org.apache.commons.io.IOUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import jakarta.annotation.PostConstruct;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.UUID;

@Service
public class FileStorageService {
    
    private static final Logger logger = LoggerFactory.getLogger(FileStorageService.class);
    
    @Value("${file.upload.dir:uploads}")
    private String uploadDir;
    
    private static final String FACES_DIR = "faces";
    private static final String ATTENDANCE_DIR = "attendance";
    
    public FileStorageService() {
        // No initialization in constructor - use @PostConstruct instead
    }
    
    @PostConstruct
    private void initializeDirs() {
        try {
            Path uploadsPath = Paths.get(uploadDir);
            Path facesPath = uploadsPath.resolve(FACES_DIR);
            Path attendancePath = uploadsPath.resolve(ATTENDANCE_DIR);
            
            Files.createDirectories(uploadsPath);
            Files.createDirectories(facesPath);
            Files.createDirectories(attendancePath);
            
            logger.info("Upload directories initialized: {}", uploadDir);
        } catch (IOException e) {
            logger.error("Error initializing upload directories", e);
        }
    }
    
    /**
     * Save uploaded file to faces directory
     */
    public String saveFaceImage(MultipartFile file, String filenamePrefix) throws IOException {
        if (file == null || file.isEmpty()) {
            logger.debug("No file uploaded");
            return null;
        }
        
        return saveFile(file, FACES_DIR, filenamePrefix);
    }
    
    /**
     * Save uploaded file to attendance directory
     */
    public String saveAttendanceImage(MultipartFile file, String filenamePrefix) throws IOException {
        if (file == null || file.isEmpty()) {
            logger.debug("No file uploaded");
            return null;
        }
        
        return saveFile(file, ATTENDANCE_DIR, filenamePrefix);
    }
    
    /**
     * Generic file save method
     */
    private String saveFile(MultipartFile file, String subdirectory, String filenamePrefix) throws IOException {
        logger.debug("Saving file - filename: '{}', content_type: '{}'", file.getOriginalFilename(), file.getContentType());
        
        String extension = getFileExtension(file.getOriginalFilename());
        String filename = filenamePrefix + extension;
        
        Path directoryPath = Paths.get(uploadDir).resolve(subdirectory);
        Path filePath = directoryPath.resolve(filename);
        
        // Handle filename conflicts
        int counter = 1;
        while (Files.exists(filePath)) {
            filename = filenamePrefix + "_" + counter + extension;
            filePath = directoryPath.resolve(filename);
            counter++;
        }
        
        logger.debug("Writing file to: {}", filePath);
        
        try {
            Files.write(filePath, file.getBytes());
            logger.debug("File written successfully, size: {} bytes", file.getSize());
            
            // Return relative path
            String relativePath = uploadDir + File.separator + subdirectory + File.separator + filename;
            relativePath = relativePath.replace("\\", "/");
            logger.debug("Returning relative path: {}", relativePath);
            
            return relativePath;
        } catch (IOException e) {
            logger.error("Error saving file: {}", e.getMessage(), e);
            // Clean up partial file if it exists
            if (Files.exists(filePath)) {
                Files.delete(filePath);
            }
            throw e;
        }
    }
    
    /**
     * Get file extension from filename
     */
    private String getFileExtension(String filename) {
        if (filename == null || filename.isEmpty()) {
            return ".jpg";
        }
        
        int lastDot = filename.lastIndexOf('.');
        if (lastDot > 0) {
            return filename.substring(lastDot).toLowerCase();
        }
        return ".jpg";
    }
    
    /**
     * Delete file
     */
    public void deleteFile(String filePath) {
        try {
            Path path = Paths.get(filePath);
            if (Files.exists(path)) {
                Files.delete(path);
                logger.info("File deleted: {}", filePath);
            }
        } catch (IOException e) {
            logger.error("Error deleting file: {}", e.getMessage(), e);
        }
    }
    
    /**
     * Get file content
     */
    public byte[] getFileContent(String filePath) throws IOException {
        Path path = Paths.get(filePath);
        if (!Files.exists(path)) {
            throw new IOException("File not found: " + filePath);
        }
        return Files.readAllBytes(path);
    }
    
    /**
     * Check if file exists
     */
    public boolean fileExists(String filePath) {
        return Files.exists(Paths.get(filePath));
    }
}
