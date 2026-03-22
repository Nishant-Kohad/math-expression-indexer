package com.example.mei.controller;

import com.example.mei.model.ExpressionResult;
import com.example.mei.repository.ExpressionRepository;
import com.example.mei.service.PdfService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.*;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/pdf")
@CrossOrigin(origins = "*")
public class PdfController {

    @Autowired
    private PdfService pdfService;

    @Autowired
    private ExpressionRepository expressionRepository;

    // ----------------------------------------------------------------
    // POST /api/pdf/upload
    // Accepts a PDF, extracts math expressions, persists, and returns them.
    // ----------------------------------------------------------------
    @PostMapping("/upload")
    public ResponseEntity<?> uploadPdf(@RequestParam("file") MultipartFile file) {
        if (file.isEmpty()) {
            return ResponseEntity.badRequest().body("Please upload a PDF file.");
        }
        try {
            List<ExpressionResult> expressions = pdfService.extractMathExpressions(file);

            Map<String, Object> response = new LinkedHashMap<>();
            response.put("fileName", file.getOriginalFilename());
            response.put("totalExpressions", expressions.size());
            response.put("results", expressions);

            return ResponseEntity.ok(response);
        } catch (IOException e) {
            return ResponseEntity.internalServerError()
                    .body("Error processing PDF: " + e.getMessage());
        }
    }

    // ----------------------------------------------------------------
    // GET /api/pdf/history
    // Returns all indexed PDFs grouped by filename, newest first.
    // ----------------------------------------------------------------
    @GetMapping("/history")
    public ResponseEntity<?> getHistory() {
        List<ExpressionResult> all = expressionRepository.findAllByOrderByIndexedAtDesc();

        // Group by pdfName, preserving insertion order (newest PDF first)
        Map<String, List<ExpressionResult>> grouped = all.stream()
                .collect(Collectors.groupingBy(
                        ExpressionResult::getPdfName,
                        LinkedHashMap::new,
                        Collectors.toList()));

        List<Map<String, Object>> result = new ArrayList<>();
        grouped.forEach((pdfName, expressions) -> {
            Map<String, Object> entry = new LinkedHashMap<>();
            entry.put("pdfName", pdfName);
            entry.put("count", expressions.size());
            entry.put("indexedAt", expressions.get(0).getIndexedAt());
            entry.put("expressions", expressions);
            result.add(entry);
        });

        return ResponseEntity.ok(result);
    }

    // ----------------------------------------------------------------
    // GET /api/pdf/export/csv
    // Downloads all indexed expressions as a CSV file.
    // ----------------------------------------------------------------
    @GetMapping("/export/csv")
    public ResponseEntity<String> exportCsv() {
        List<ExpressionResult> all = expressionRepository.findAllByOrderByIndexedAtDesc();

        StringBuilder csv = new StringBuilder();
        csv.append("id,expression,pageNumber,context,pdfName,indexedAt\n");

        for (ExpressionResult e : all) {
            csv.append(e.getId()).append(",")
               .append(escapeCsv(e.getExpression())).append(",")
               .append(e.getPageNumber()).append(",")
               .append(escapeCsv(e.getContext())).append(",")
               .append(escapeCsv(e.getPdfName())).append(",")
               .append(e.getIndexedAt()).append("\n");
        }

        return ResponseEntity.ok()
                .header("Content-Disposition", "attachment; filename=\"expressions.csv\"")
                .header("Content-Type", "text/csv; charset=UTF-8")
                .body(csv.toString());
    }

    // ----------------------------------------------------------------
    // Helpers
    // ----------------------------------------------------------------
    private String escapeCsv(String value) {
        if (value == null) return "";
        if (value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r")) {
            return "\"" + value.replace("\"", "\"\"") + "\"";
        }
        return value;
    }
}
