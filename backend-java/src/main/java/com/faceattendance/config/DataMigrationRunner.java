package com.faceattendance.config;

import com.faceattendance.model.AttendanceRecord;
import com.faceattendance.repository.AttendanceRecordRepository;
import com.faceattendance.repository.StudentRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.sql.*;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * Data Migration Runner - Imports attendance records from migration file on startup
 */
@Component
public class DataMigrationRunner implements ApplicationRunner {
    
    private static final Logger logger = LoggerFactory.getLogger(DataMigrationRunner.class);
    
    @Autowired
    private StudentRepository studentRepository;
    
    @Autowired
    private AttendanceRecordRepository attendanceRepository;
    
    private static final String MIGRATION_DATA_FILE = "migration_data.csv";
    
    @Override
    public void run(ApplicationArguments args) throws Exception {
        // Check if migration file exists
        File migrationFile = new File(MIGRATION_DATA_FILE);
        if (!migrationFile.exists()) {
            logger.debug("No migration data file found: {}", MIGRATION_DATA_FILE);
            return;
        }
        
        logger.info("Found migration data file, starting import...");
        importAttendanceRecords(migrationFile);
    }
    
    private void importAttendanceRecords(File csvFile) {
        try (BufferedReader reader = new BufferedReader(new FileReader(csvFile))) {
            int count = 0;
            int skipped = 0;
            String line;
            
            while ((line = reader.readLine()) != null) {
                if (line.trim().isEmpty() || line.startsWith("#")) {
                    continue;
                }
                
                try {
                    AttendanceRecord record = parseCSVLine(line);
                    if (record != null) {
                        // Check if record already exists
                        if (attendanceRepository.findByStudentIdAndAttendanceDate(
                                record.getStudentId(), 
                                record.getAttendanceDate()).isEmpty()) {
                            
                            attendanceRepository.save(record);
                            count++;
                        } else {
                            skipped++;
                        }
                    }
                } catch (Exception e) {
                    logger.warn("Error parsing line: {} - {}", line, e.getMessage());
                }
            }
            
            logger.info("Migration completed: {} imported, {} skipped", count, skipped);
            
        } catch (IOException e) {
            logger.error("Error reading migration file: {}", e.getMessage(), e);
        }
    }
    
    private AttendanceRecord parseCSVLine(String line) {
        try {
            // CSV format: studentId,attendanceDate,checkInTime,photoPath,confidence
            String[] parts = line.split(",(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)"); // Handle quoted values
            
            if (parts.length < 3) {
                return null;
            }
            
            String studentId = parts[0].trim().replaceAll("\"", "");
            LocalDate attendanceDate = LocalDate.parse(parts[1].trim());
            LocalDateTime checkInTime = LocalDateTime.parse(parts[2].trim());
            String photoPath = parts.length > 3 ? parts[3].trim().replaceAll("\"", "") : "";
            Double confidence = parts.length > 4 ? parseDouble(parts[4].trim()) : null;
            
            AttendanceRecord record = new AttendanceRecord();
            record.setStudentId(studentId);
            record.setAttendanceDate(attendanceDate);
            record.setCheckInTime(checkInTime);
            record.setPhotoPath(photoPath.isEmpty() ? null : photoPath);
            record.setConfidence(confidence);
            
            return record;
        } catch (Exception e) {
            logger.debug("Could not parse line: {} - {}", line, e.getMessage());
            return null;
        }
    }
    
    private Double parseDouble(String value) {
        try {
            return Double.parseDouble(value);
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
