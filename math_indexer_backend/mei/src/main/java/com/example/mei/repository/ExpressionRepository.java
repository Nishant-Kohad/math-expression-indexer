package com.example.mei.repository;

import com.example.mei.model.ExpressionResult;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ExpressionRepository extends JpaRepository<ExpressionResult, Long> {

    List<ExpressionResult> findByPdfNameOrderByPageNumberAsc(String pdfName);

    List<ExpressionResult> findAllByOrderByIndexedAtDesc();

    @Query("SELECT DISTINCT e.pdfName FROM ExpressionResult e ORDER BY e.pdfName")
    List<String> findDistinctPdfNames();

    long countByPdfName(String pdfName);
}
