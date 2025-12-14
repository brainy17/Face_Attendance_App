package com.faceattendance.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public class AttendanceDTO {
    @JsonProperty("student_id")
    private String studentId;
    
    private String name;
    private String course;
    private String date;
    private String timestamp;
    private String time;
    private String status;
    private Double confidence;
    
    @JsonProperty("photo_path")
    private String photoPath;
    
    @JsonProperty("photo_url")
    private String photoUrl;
    
    private Long id;
    
    // Constructors
    public AttendanceDTO() {}
    
    public AttendanceDTO(Long id, String studentId, String name, String course, 
                        String date, String timestamp, String time, String status,
                        Double confidence, String photoPath, String photoUrl) {
        this.id = id;
        this.studentId = studentId;
        this.name = name;
        this.course = course;
        this.date = date;
        this.timestamp = timestamp;
        this.time = time;
        this.status = status;
        this.confidence = confidence;
        this.photoPath = photoPath;
        this.photoUrl = photoUrl;
    }
    
    // Getters and Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    
    public String getStudentId() { return studentId; }
    public void setStudentId(String studentId) { this.studentId = studentId; }
    
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    
    public String getCourse() { return course; }
    public void setCourse(String course) { this.course = course; }
    
    public String getDate() { return date; }
    public void setDate(String date) { this.date = date; }
    
    public String getTimestamp() { return timestamp; }
    public void setTimestamp(String timestamp) { this.timestamp = timestamp; }
    
    public String getTime() { return time; }
    public void setTime(String time) { this.time = time; }
    
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    
    public Double getConfidence() { return confidence; }
    public void setConfidence(Double confidence) { this.confidence = confidence; }
    
    public String getPhotoPath() { return photoPath; }
    public void setPhotoPath(String photoPath) { this.photoPath = photoPath; }
    
    public String getPhotoUrl() { return photoUrl; }
    public void setPhotoUrl(String photoUrl) { this.photoUrl = photoUrl; }
}
