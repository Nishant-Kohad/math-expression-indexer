package com.example.mei.service;

import com.example.mei.model.ExpressionResult;
import com.example.mei.repository.ExpressionRepository;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.text.PDFTextStripper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

@Service
public class PdfService {

    @Autowired
    private ExpressionRepository expressionRepository;

    public List<ExpressionResult> extractMathExpressions(MultipartFile file) throws IOException {
        List<ExpressionResult> results = new ArrayList<>();
        String fileName = file.getOriginalFilename();

        try (PDDocument document = PDDocument.load(file.getInputStream())) {
            PDFTextStripper stripper = new PDFTextStripper();
            int totalPages = document.getNumberOfPages();

            for (int page = 1; page <= totalPages; page++) {
                stripper.setStartPage(page);
                stripper.setEndPage(page);
                String text = stripper.getText(document);
                String[] lines = text.split("\\r?\\n");

                for (int i = 0; i < lines.length; i++) {
                    String cleanedLine = lines[i].trim();
                    if (isMathExpression(cleanedLine)) {
                        String context = buildContext(lines, i);
                        results.add(new ExpressionResult(cleanedLine, page, context, fileName));
                    }
                }
            }
        }

        // Persist all extracted expressions
        expressionRepository.saveAll(results);
        return results;
    }

    /**
     * Builds surrounding context for an expression at lines[index].
     * Looks up to 2 lines back and 2 lines forward for non-empty content.
     */
    private String buildContext(String[] lines, int index) {
        StringBuilder ctx = new StringBuilder();

        // Scan backwards for the nearest non-empty, non-math line
        for (int i = index - 1; i >= Math.max(0, index - 2); i--) {
            String prev = lines[i].trim();
            if (!prev.isEmpty() && !isMathExpression(prev)) {
                ctx.insert(0, prev + " … ");
                break;
            }
        }

        // Scan forwards for the nearest non-empty, non-math line
        for (int i = index + 1; i <= Math.min(lines.length - 1, index + 2); i++) {
            String next = lines[i].trim();
            if (!next.isEmpty() && !isMathExpression(next)) {
                ctx.append(" … ").append(next);
                break;
            }
        }

        String result = ctx.toString().trim();
        // Remove stray leading/trailing separators
        result = result.replaceAll("^…\\s*", "").replaceAll("\\s*…$", "").trim();
        return result.isEmpty() ? "(no surrounding context)" : result;
    }

    /**
     * Scores a line to decide if it is a mathematical expression.
     * Returns true when score >= 4.
     */
    private boolean isMathExpression(String line) {
        if (line == null || line.isBlank()) return false;
        String t = line.trim();
        if (t.length() < 3) return false;

        // --- Reject non-math patterns ---
        // Year ranges like (1845-1918)
        if (t.matches("\\(?\\d{4}[-–]\\d{4}\\)?")) return false;
        // Reprint / edition notes
        if (t.toLowerCase().contains("reprint") || t.toLowerCase().contains("edition")) return false;
        // Pure decimal numbers (e.g. "3.14")
        if (t.matches("^[+-]?\\d+(\\.\\d+)?$")) return false;
        // Long prose sentences (> 12 words)
        if (t.split("\\s+").length > 12) return false;

        int score = 0;

        // --- Strong LaTeX signals ---
        if (t.startsWith("$") && t.endsWith("$") && t.length() > 2) score += 7;
        if (t.startsWith("\\[") && t.endsWith("\\]")) score += 7;
        if (t.startsWith("\\(") && t.endsWith("\\)")) score += 6;
        if (t.contains("\\begin{equation}") || t.contains("\\begin{align}") ||
            t.contains("\\begin{math}"))      score += 7;

        // LaTeX command names
        if (t.matches(".*\\\\(frac|sqrt|sum|int|prod|lim|infty|partial|nabla|" +
                       "alpha|beta|gamma|delta|epsilon|theta|lambda|mu|nu|xi|pi|rho|" +
                       "sigma|tau|phi|chi|psi|omega|" +
                       "cdot|times|div|pm|mp|leq|geq|neq|approx|equiv|sim|" +
                       "rightarrow|leftarrow|Rightarrow|Leftarrow|leftrightarrow|" +
                       "hat|bar|vec|dot|ddot|tilde|overline|underline|" +
                       "mathbb|mathbf|mathcal|mathrm|text|quad|qquad).*")) score += 5;

        // --- Classic math signals ---
        if (t.contains("="))                          score += 4;
        if (t.matches(".*[+\\-*/^<>≤≥≠≈].*"))        score += 3;
        if (t.matches(".*\\d+.*"))                    score += 1;
        if (t.matches(".*[(){}\\[\\]].*"))            score += 1;

        // Trig, calculus, stats function names
        if (t.matches(".*\\b(sin|cos|tan|cot|sec|csc|" +
                       "log|ln|exp|sqrt|lim|sum|int|" +
                       "max|min|sup|inf|det|arg|rank|span|ker|dim|" +
                       "E|Var|Cov|P)\\b.*"))          score += 4;

        // Variable-operator-variable pattern (e.g. "a + b", "x = y^2")
        if (t.matches(".*[a-zA-Z]\\s*[+\\-*/=^]\\s*[a-zA-Z0-9].*")) score += 3;

        // Subscript/superscript notation (e.g. "x_1", "a^{n+1}")
        if (t.matches(".*[a-zA-Z][_^][a-zA-Z0-9{].*")) score += 3;

        // Fraction-like pattern (digit / digit)
        if (t.matches(".*\\d+\\s*/\\s*\\d+.*"))       score += 2;

        return score >= 4;
    }
}
