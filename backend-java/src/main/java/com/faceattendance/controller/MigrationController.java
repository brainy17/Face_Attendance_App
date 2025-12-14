package com.faceattendance.controller;

import com.faceattendance.model.AttendanceRecord;
import com.faceattendance.model.Student;
import com.faceattendance.repository.AttendanceRecordRepository;
import com.faceattendance.repository.StudentRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;

/**
 * Migration Controller for importing data from old backend
 */
@RestController
@RequestMapping("/api/migrate")
@CrossOrigin(origins = {"http://localhost:8001", "http://localhost:3000", "http://10.0.2.2", "http://127.0.0.1"})
public class MigrationController {
    
    private static final Logger logger = LoggerFactory.getLogger(MigrationController.class);
    
    @Autowired
    private StudentRepository studentRepository;
    
    @Autowired
    private AttendanceRecordRepository attendanceRepository;
    
    /**
     * Import attendance records from old backend
     * Expected JSON payload:
     * {
     *   "studentId": "23CS041",
     *   "attendanceDate": "2025-10-13",
     *   "checkInTime": "2025-10-13T07:55:37",
     *   "photoPath": "uploads/attendance/attendance_23CS041_20251013075537.jpg",
     *   "confidence": 0.95
     * }
     */
    @PostMapping("/attendance")
    public ResponseEntity<?> importAttendanceRecord(@RequestBody Map<String, Object> payload) {
        try {
            String studentId = (String) payload.get("studentId");
            String attendanceDateStr = (String) payload.get("attendanceDate");
            String checkInTimeStr = (String) payload.get("checkInTime");
            String photoPath = (String) payload.get("photoPath");
            Object confidenceObj = payload.get("confidence");
            
            // Validate required fields
            if (studentId == null || studentId.isEmpty()) {
                return ResponseEntity.badRequest().body(Map.of(
                        "success", false,
                        "message", "studentId is required"
                ));
            }
            if (attendanceDateStr == null || attendanceDateStr.isEmpty()) {
                return ResponseEntity.badRequest().body(Map.of(
                        "success", false,
                        "message", "attendanceDate is required"
                ));
            }
            
            // Check if student exists
            Optional<Student> studentOpt = studentRepository.findByStudentId(studentId);
            if (studentOpt.isEmpty()) {
                return ResponseEntity.badRequest().body(Map.of(
                        "success", false,
                        "message", "Student not found: " + studentId
                ));
            }
            
            // Parse dates
            LocalDate attendanceDate = LocalDate.parse(attendanceDateStr);
            LocalDateTime checkInTime = LocalDateTime.now();
            
            if (checkInTimeStr != null && !checkInTimeStr.isEmpty()) {
                try {
                    // Try parsing as ISO format first
                    checkInTime = LocalDateTime.parse(checkInTimeStr);
                } catch (Exception e) {
                    logger.warn("Could not parse checkInTime: {}, using current time", checkInTimeStr);
                }
            }
            
            // Parse confidence
            Double confidence = null;
            if (confidenceObj != null) {
                if (confidenceObj instanceof Number) {
                    confidence = ((Number) confidenceObj).doubleValue();
                } else if (confidenceObj instanceof String) {
                    try {
                        confidence = Double.parseDouble((String) confidenceObj);
                    } catch (NumberFormatException e) {
                        logger.warn("Could not parse confidence: {}", confidenceObj);
                    }
                }
            }
            
            // Check for duplicate
            Optional<AttendanceRecord> existing = attendanceRepository
                    .findByStudentIdAndAttendanceDate(studentId, attendanceDate);
            
            if (existing.isPresent()) {
                logger.warn("Attendance record already exists for {} on {}", studentId, attendanceDate);
                return ResponseEntity.ok(Map.of(
                        "success", false,
                        "message", "Attendance record already exists for this student on this date"
                ));
            }
            
            // Create and save attendance record
            AttendanceRecord record = new AttendanceRecord();
            record.setStudentId(studentId);
            record.setAttendanceDate(attendanceDate);
            record.setCheckInTime(checkInTime);
            record.setPhotoPath(photoPath);
            record.setConfidence(confidence);
            
            record = attendanceRepository.save(record);
            
            logger.info("Attendance record imported for {} on {}", studentId, attendanceDate);
            
            return ResponseEntity.ok(Map.of(
                    "success", true,
                    "message", "Attendance record imported successfully",
                    "id", record.getId()
            ));
            
        } catch (Exception e) {
            logger.error("Error importing attendance record: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(Map.of(
                    "success", false,
                    "message", "Error importing attendance record: " + e.getMessage()
            ));
        }
    }
    
    /**
     * Clear all data (for testing/reset purposes)
     */
    @DeleteMapping("/clear")
    public ResponseEntity<?> clearAllData(@RequestParam(required = false) String confirmation) {
        try {
            if (!"yes-clear-all".equals(confirmation)) {
                return ResponseEntity.badRequest().body(Map.of(
                        "success", false,
                        "message", "Please confirm by passing confirmation=yes-clear-all"
                ));
            }
            
            long recordsDeleted = attendanceRepository.count();
            long studentsDeleted = studentRepository.count();
            
            attendanceRepository.deleteAll();
            studentRepository.deleteAll();
            
            logger.warn("All data cleared: {} attendance records, {} students", recordsDeleted, studentsDeleted);
            
            return ResponseEntity.ok(Map.of(
                    "success", true,
                    "message", "All data cleared",
                    "attendance_records_deleted", recordsDeleted,
                    "students_deleted", studentsDeleted
            ));
            
        } catch (Exception e) {
            logger.error("Error clearing data: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(Map.of(
                    "success", false,
                    "message", "Error clearing data"
            ));
        }
    }
}
