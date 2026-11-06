package com.contaca.backend.repository;

import com.contaca.backend.entity.FoodEntryEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface FoodEntryRepository extends JpaRepository<FoodEntryEntity, UUID> {
    List<FoodEntryEntity> findByUserIdOrderByConsumedAtDesc(UUID userId);
    long countByUserId(UUID userId);
    void deleteByUserId(UUID userId);
}
