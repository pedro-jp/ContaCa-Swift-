package com.contaca.backend.repository;

import com.contaca.backend.entity.AiAnalysisEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface AiAnalysisRepository extends JpaRepository<AiAnalysisEntity, UUID> {
    List<AiAnalysisEntity> findByUserIdOrderByCreatedAtDesc(UUID userId);
    long countByUserId(UUID userId);
    void deleteByUserId(UUID userId);
}
