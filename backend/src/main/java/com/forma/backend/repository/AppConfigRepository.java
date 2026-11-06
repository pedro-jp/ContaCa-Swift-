package com.forma.backend.repository;

import com.forma.backend.entity.AppConfigEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface AppConfigRepository extends JpaRepository<AppConfigEntity, String> {
}
