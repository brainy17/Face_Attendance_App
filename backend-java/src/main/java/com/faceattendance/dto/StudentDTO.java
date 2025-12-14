package com.faceattendance.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.time.LocalDateTime;

public class StudentDTO {
    @JsonProperty("student_id")
    private String studentId;
    
    private String name;
    private String email;
    private String course;
    
    @JsonProperty("face_image_path")
    private String faceImagePath;
    
    @JsonProperty("face_image_url")
    private String faceImageUrl;
    
    @JsonProperty("registration_date")
    private String registrationDate;
    
    // Constructors
    public StudentDTO() {}
    
    public StudentDTO(String studentId, String name, String email, String course, 
                     String faceImagePath, String faceImageUrl, String registrationDate) {
        this.studentId = studentId;
        this.name = name;
        this.email = email;
        this.course = course;
        this.faceImagePath = faceImagePath;
        this.faceImageUrl = faceImageUrl;
        this.registrationDate = registrationDate;
    }
    
    // Getters and Setters
    public String getStudentId() { return studentId; }
    public void setStudentId(String studentId) { this.studentId = studentId; }
    
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    
    public String getCourse() { return course; }
    public void setCourse(String course) { this.course = course; }
    
    public String getFaceImagePath() { return faceImagePath; }
    public void setFaceImagePath(String faceImagePath) { this.faceImagePath = faceImagePath; }
    
    public String getFaceImageUrl() { return faceImageUrl; }
    public void setFaceImageUrl(String faceImageUrl) { this.faceImageUrl = faceImageUrl; }
    
    public String getRegistrationDate() { return registrationDate; }
    public void setRegistrationDate(String registrationDate) { this.registrationDate = registrationDate; }
}
