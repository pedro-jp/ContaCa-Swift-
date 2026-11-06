package com.contaca.backend.repository;

import com.contaca.backend.entity.WorkoutEntryEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface WorkoutEntryRepository extends JpaRepository<WorkoutEntryEntity, UUID> {
    List<WorkoutEntryEntity> findByUserIdOrderByWorkoutDateDesc(UUID userId);
    long countByUserId(UUID userId);
    void deleteByUserId(UUID userId);
}
