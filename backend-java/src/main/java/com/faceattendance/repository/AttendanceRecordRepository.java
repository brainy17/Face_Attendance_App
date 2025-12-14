package com.faceattendance.repository;

import com.faceattendance.model.AttendanceRecord;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
public interface AttendanceRecordRepository extends JpaRepository<AttendanceRecord, Long> {
    Optional<AttendanceRecord> findByStudentIdAndAttendanceDate(String studentId, LocalDate attendanceDate);
    List<AttendanceRecord> findByAttendanceDateBetween(LocalDate startDate, LocalDate endDate);
    List<AttendanceRecord> findByStudentIdAndAttendanceDateBetween(String studentId, LocalDate startDate, LocalDate endDate);
    List<AttendanceRecord> findByAttendanceDate(LocalDate attendanceDate);
    long countByAttendanceDate(LocalDate attendanceDate);
}
