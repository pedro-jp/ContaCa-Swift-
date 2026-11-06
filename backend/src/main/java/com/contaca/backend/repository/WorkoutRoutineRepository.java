package com.contaca.backend.repository;

import com.contaca.backend.entity.WorkoutRoutineEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface WorkoutRoutineRepository extends JpaRepository<WorkoutRoutineEntity, UUID> {
    List<WorkoutRoutineEntity> findByUserIdOrderByCreatedAtDesc(UUID userId);
    long countByUserId(UUID userId);
    void deleteByUserId(UUID userId);
}
