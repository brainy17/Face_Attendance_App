package com.faceattendance.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.io.File;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.*;

@Service
public class FaceRecognitionService {
    
    private static final Logger logger = LoggerFactory.getLogger(FaceRecognitionService.class);
    private static final double MIN_RECOGNITION_CONFIDENCE = 0.5;
    private boolean isEnabled = false;
    
    public FaceRecognitionService() {
        try {
            // Check if cascade files are available
            File cascadeDir = new File("src/main/resources/cascade");
            if (cascadeDir.exists()) {
                isEnabled = true;
                logger.info("Face recognition cascade files found");
            } else {
                logger.warn("Face recognition cascade files not found - will use basic detection");
                isEnabled = false;
            }
        } catch (Exception e) {
            logger.error("Error initializing face recognizer: {}", e.getMessage());
            isEnabled = false;
        }
    }
    
    /**
     * Extract face from image (stub - OpenCV would be needed for real implementation)
     */
    public byte[] extractFace(String imagePath) {
        try {
            if (!isEnabled) {
                logger.warn("Face extraction not available - cascade not loaded");
                // Return file as-is for now
                return Files.readAllBytes(Paths.get(imagePath));
            }
            return Files.readAllBytes(Paths.get(imagePath));
        } catch (Exception e) {
            logger.error("Error extracting face from {}: {}", imagePath, e.getMessage());
            return null;
        }
    }
    
    /**
     * Compare two faces (stub - returns simulated confidence)
     */
    public double[] compareFaces(String face1Path, String face2Path) {
        try {
            if (!isEnabled) {
                // Without OpenCV, we can't do real face recognition
                // For demo purposes, return a confidence based on file similarity
                long file1Size = new File(face1Path).length();
                long file2Size = new File(face2Path).length();
                
                double sizeRatio = Math.min(file1Size, file2Size) / (double) Math.max(file1Size, file2Size);
                double confidence = sizeRatio * 0.6 + 0.2; // Fake confidence between 0.2 and 0.8
                boolean isMatch = confidence >= MIN_RECOGNITION_CONFIDENCE;
                
                logger.info("Face comparison (simulated): confidence={}, match={}", 
                        String.format("%.3f", confidence), isMatch);
                return new double[]{confidence, isMatch ? 1.0 : 0.0};
            }
            
            // Real OpenCV implementation would go here
            return new double[]{0.0, 0.0};
        } catch (Exception e) {
            logger.error("Error comparing faces: {}", e.getMessage());
            return new double[]{0.0, 0.0};
        }
    }
    
    /**
     * Find best match among registered faces
     */
    public Map<String, Object> findBestMatch(String candidateFacePath, List<Map.Entry<String, String>> registeredFaces) {
        try {
            double bestConfidence = 0.0;
            String bestMatch = null;
            
            for (Map.Entry<String, String> entry : registeredFaces) {
                String studentId = entry.getKey();
                String registeredFacePath = entry.getValue();
                
                double[] result = compareFaces(candidateFacePath, registeredFacePath);
                double confidence = result[0];
                
                if (confidence > bestConfidence) {
                    bestConfidence = confidence;
                    bestMatch = studentId;
                }
            }
            
            if (bestConfidence >= MIN_RECOGNITION_CONFIDENCE) {
                Map<String, Object> matchResult = new HashMap<>();
                matchResult.put("student_id", bestMatch);
                matchResult.put("confidence", bestConfidence);
                return matchResult;
            }
            
            return null;
        } catch (Exception e) {
            logger.error("Error finding best match: {}", e.getMessage());
            return null;
        }
    }
    
    public boolean isLoaded() {
        return isEnabled;
    }
}
