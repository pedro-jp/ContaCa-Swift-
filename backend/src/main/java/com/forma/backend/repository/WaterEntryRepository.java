package com.forma.backend.repository;

import com.forma.backend.entity.WaterEntryEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface WaterEntryRepository extends JpaRepository<WaterEntryEntity, UUID> {
    List<WaterEntryEntity> findByUserIdOrderByEntryDateDesc(UUID userId);
    long countByUserId(UUID userId);
    void deleteByUserId(UUID userId);
}
