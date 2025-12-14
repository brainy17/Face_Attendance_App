package com.faceattendance.controller;

import com.faceattendance.dto.AttendanceDTO;
import com.faceattendance.dto.StudentDTO;
import com.faceattendance.model.AttendanceRecord;
import com.faceattendance.model.Student;
import com.faceattendance.repository.AttendanceRecordRepository;
import com.faceattendance.repository.StudentRepository;
import com.faceattendance.service.FaceRecognitionService;
import com.faceattendance.service.FileStorageService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "*", allowedHeaders = "*")
public class AttendanceController {
    
    private static final Logger logger = LoggerFactory.getLogger(AttendanceController.class);
    private static final String APP_VERSION = "2.0.0";
    
    @Autowired
    private StudentRepository studentRepository;
    
    @Autowired
    private AttendanceRecordRepository attendanceRepository;
    
    @Autowired
    private FaceRecognitionService faceRecognitionService;
    
    @Autowired
    private FileStorageService fileStorageService;
    
    @Value("${app.version:2.0.0}")
    private String appVersion;
    
    /**
     * Health check endpoint
     */
    @GetMapping("/health")
    public ResponseEntity<?> healthCheck() {
        try {
            long studentCount = studentRepository.count();
            long todayAttendance = attendanceRepository.countByAttendanceDate(LocalDate.now());
            
            return ResponseEntity.ok(Map.of(
                    "status", "ok",
                    "message", "Backend is running",
                    "version", appVersion,
                    "students", studentCount,
                    "today_attendance", todayAttendance
            ));
        } catch (Exception e) {
            logger.error("Health check failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(Map.of(
                    "status", "unhealthy",
                    "error", e.getMessage()
            ));
        }
    }
    
    /**
     * Detailed health check
     */
    @GetMapping("/health/detailed")
    public ResponseEntity<?> healthCheckDetailed() {
        try {
            boolean dbConnected = studentRepository.count() >= 0;
            boolean faceRecognitionLoaded = faceRecognitionService.isLoaded();
            
            return ResponseEntity.ok(Map.of(
                    "status", "healthy",
                    "version", appVersion,
                    "database", dbConnected ? "connected" : "error",
                    "face_recognition", faceRecognitionLoaded ? "loaded" : "not_loaded",
                    "timestamp", LocalDateTime.now().toString()
            ));
        } catch (Exception e) {
            logger.error("Detailed health check failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(Map.of(
                    "status", "unhealthy",
                    "database", "error",
                    "error", e.getMessage()
            ));
        }
    }
    
    /**
     * Register a new student
     */
    @PostMapping("/register")
    public ResponseEntity<?> registerStudent(
            @RequestParam String student_id,
            @RequestParam String name,
            @RequestParam(required = false) String email,
            @RequestParam(required = false, name = "class") String classForm,
            @RequestParam(required = false, name = "class_section") String classSection,
            @RequestParam(required = false, name = "course") String course,
            @RequestParam(required = false) MultipartFile file) {
        
        try {
            // Input validation
            if (student_id == null || student_id.trim().isEmpty()) {
                return ResponseEntity.badRequest().body(Map.of(
                        "success", false,
                        "message", "student_id cannot be empty"
                ));
            }
            if (name == null || name.trim().isEmpty()) {
                return ResponseEntity.badRequest().body(Map.of(
                        "success", false,
                        "message", "name cannot be empty"
                ));
            }
            
            // Sanitize inputs
            student_id = student_id.trim();
            name = name.trim();
            if (email != null) {
                email = email.trim();
            }
            
            logger.info("Registration attempt for student_id='{}', name='{}'", student_id, name);
            logger.debug("File received: {}, content_type: {}", 
                    file != null ? file.getOriginalFilename() : "None",
                    file != null ? file.getContentType() : "None");
            
            // Check if student already exists
            if (studentRepository.findByStudentId(student_id).isPresent()) {
                logger.warn("Student ID {} already exists", student_id);
                return ResponseEntity.ok(Map.of(
                        "success", false,
                        "message", "Student ID already exists"
                ));
            }
            
            // Determine class section
            String finalClassSection = classSection != null ? classSection : (course != null ? course : classForm);
            
            // Save face image
            logger.info("Saving face image for student {}", student_id);
            String faceImagePath = null;
            if (file != null && !file.isEmpty()) {
                faceImagePath = fileStorageService.saveFaceImage(file, 
                        student_id + "_" + System.currentTimeMillis());
                logger.info("Face image saved to: {}", faceImagePath);
            }
            
            // Create and save student
            Student student = new Student(student_id, name, email, finalClassSection, faceImagePath);
            student = studentRepository.save(student);
            
            logger.info("Student {} registered successfully", name);
            
            return ResponseEntity.ok(Map.of(
                    "success", true,
                    "message", "Student " + name + " registered",
                    "student", serializeStudent(student)
            ));
        } catch (IOException e) {
            logger.error("Error uploading file: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(Map.of(
                    "success", false,
                    "message", "Error uploading file"
            ));
        } catch (Exception e) {
            logger.error("Error registering student: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(Map.of(
                    "success", false,
                    "message", "Error registering student"
            ));
        }
    }
    
    /**
     * List all students
     */
    @GetMapping("/students")
    public ResponseEntity<?> listStudents() {
        try {
            List<Student> students = studentRepository.findAll();
            students.sort(Comparator.comparing(Student::getName));
            
            List<StudentDTO> dtoList = students.stream()
                    .map(this::serializeStudent)
                    .collect(Collectors.toList());
            
            return ResponseEntity.ok(Map.of(
                    "success", true,
                    "students", dtoList,
                    "total", dtoList.size()
            ));
        } catch (Exception e) {
            logger.error("Error listing students: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(Map.of(
                    "success", false,
                    "message", "Error listing students"
            ));
        }
    }
    
    /**
     * Delete a student
     */
    @DeleteMapping("/students/{student_id}")
    public ResponseEntity<?> deleteStudent(@PathVariable String student_id) {
        try {
            Optional<Student> studentOpt = studentRepository.findByStudentId(student_id);
            
            if (studentOpt.isEmpty()) {
                return ResponseEntity.ok(Map.of(
                        "success", false,
                        "message", "Student not found"
                ));
            }
            
            Student student = studentOpt.get();
            
            // Delete face image if exists
            if (student.getFaceImagePath() != null && !student.getFaceImagePath().isEmpty()) {
                fileStorageService.deleteFile(student.getFaceImagePath());
            }
            
            studentRepository.delete(student);
            logger.info("Student {} deleted", student_id);
            
            return ResponseEntity.ok(Map.of(
                    "success", true,
                    "message", "Student deleted"
            ));
        } catch (Exception e) {
            logger.error("Error deleting student: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(Map.of(
                    "success", false,
                    "message", "Error deleting student"
            ));
        }
    }
    
    /**
     * Helper method to serialize student
     */
    private StudentDTO serializeStudent(Student student) {
        String faceImageUrl = student.getFaceImagePath() != null ? 
                "/" + student.getFaceImagePath().replace("\\", "/") : null;
        
        return new StudentDTO(
                student.getStudentId(),
                student.getName(),
                student.getEmail(),
                student.getClassSection(),
                student.getFaceImagePath(),
                faceImageUrl,
                student.getCreatedAt().toString()
        );
    }
    
    /**
     * Helper method to serialize attendance
     */
    private AttendanceDTO serializeAttendance(AttendanceRecord record, Student student) {
        String status = record.getPhotoPath() == null ? "Absent" : "Present";
        String photoUrl = record.getPhotoPath() != null ? 
                "/" + record.getPhotoPath().replace("\\", "/") : null;
        
        DateTimeFormatter timeFormatter = DateTimeFormatter.ofPattern("HH:mm:ss");
        String time = record.getCheckInTime().format(timeFormatter);
        
        return new AttendanceDTO(
                record.getId(),
                student.getStudentId(),
                student.getName(),
                student.getClassSection(),
                record.getAttendanceDate().toString(),
                record.getCheckInTime().toString(),
                time,
                status,
                record.getConfidence(),
                record.getPhotoPath(),
                photoUrl
        );
    }
}
