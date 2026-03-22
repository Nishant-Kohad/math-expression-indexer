package com.example.mei.model;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "expressions")
public class ExpressionResult {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 500)
    private String expression;

    private int pageNumber;

    @Column(length = 1000)
    private String context;

    private String pdfName;

    private LocalDateTime indexedAt;

    public ExpressionResult() {}

    public ExpressionResult(String expression, int pageNumber, String context, String pdfName) {
        this.expression = expression;
        this.pageNumber = pageNumber;
        this.context = context;
        this.pdfName = pdfName;
        this.indexedAt = LocalDateTime.now();
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getExpression() { return expression; }
    public void setExpression(String expression) { this.expression = expression; }

    public int getPageNumber() { return pageNumber; }
    public void setPageNumber(int pageNumber) { this.pageNumber = pageNumber; }

    public String getContext() { return context; }
    public void setContext(String context) { this.context = context; }

    public String getPdfName() { return pdfName; }
    public void setPdfName(String pdfName) { this.pdfName = pdfName; }

    public LocalDateTime getIndexedAt() { return indexedAt; }
    public void setIndexedAt(LocalDateTime indexedAt) { this.indexedAt = indexedAt; }
}
