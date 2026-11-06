package com.forma.backend.repository;

import com.forma.backend.entity.WeightEntryEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface WeightEntryRepository extends JpaRepository<WeightEntryEntity, UUID> {
    List<WeightEntryEntity> findByUserIdOrderByEntryDateDesc(UUID userId);
    long countByUserId(UUID userId);
    void deleteByUserId(UUID userId);
}
