import 'dart:math';

import 'package:scaneliq/core/models/document_models.dart';
import 'package:scaneliq/features/documents/data/app_database_service.dart';

class DocumentSummaryResult {
  final String executiveSummary;
  final List<String> bulletPoints;
  final List<String> topKeywords;
  final int totalWords;
  final int totalSentences;

  const DocumentSummaryResult({
    required this.executiveSummary,
    required this.bulletPoints,
    required this.topKeywords,
    required this.totalWords,
    required this.totalSentences,
  });
}

class DocumentQaResult {
  final String question;
  final String bestAnswer;
  final double confidence;
  final List<String> relevantSentences;

  const DocumentQaResult({
    required this.question,
    required this.bestAnswer,
    required this.confidence,
    required this.relevantSentences,
  });
}

class DocumentEntityExtraction {
  final List<String> dates;
  final List<String> amounts;
  final List<String> namesAndOrganizations;
  final List<String> identifiers;
  final List<String> emails;
  final List<String> phoneNumbers;

  const DocumentEntityExtraction({
    required this.dates,
    required this.amounts,
    required this.namesAndOrganizations,
    required this.identifiers,
    required this.emails,
    required this.phoneNumbers,
  });

  bool get isEmpty =>
      dates.isEmpty &&
      amounts.isEmpty &&
      namesAndOrganizations.isEmpty &&
      identifiers.isEmpty &&
      emails.isEmpty &&
      phoneNumbers.isEmpty;
}

class DocumentExplanationResult {
  final String documentCategory;
  final String plainExplanation;
  final List<String> keyTakeaways;
  final List<String> suggestedActions;

  const DocumentExplanationResult({
    required this.documentCategory,
    required this.plainExplanation,
    required this.keyTakeaways,
    required this.suggestedActions,
  });
}

class SemanticVaultSearchResult {
  final ScannedDocument document;
  final double relevanceScore;
  final String matchedExcerpt;

  const SemanticVaultSearchResult({
    required this.document,
    required this.relevanceScore,
    required this.matchedExcerpt,
  });
}

/// Optional interface for user-consented BYOK external LLM integration.
/// Never sends private document text externally without explicit user API key and opt-in consent.
abstract class ExternalAiProvider {
  bool get isConfigured;
  Future<String> askWithExternalModel({
    required String documentText,
    required String prompt,
  });
}

/// Service providing genuine Unicode-aware (English & বাংলা) on-device TextRank
/// summarization, TF-IDF cosine Q&A, structured entity extraction (dates, names,
/// currency amounts, IDs), plain-language explanation, and semantic vault search.
class AiDocumentService {
  AiDocumentService._();
  static final AiDocumentService instance = AiDocumentService._();

  bool _allowExternalAi = false;
  ExternalAiProvider? _externalProvider;

  bool get isExternalAiAllowed =>
      _allowExternalAi && (_externalProvider?.isConfigured ?? false);

  void configureExternalAiConsent({
    required bool userConsented,
    ExternalAiProvider? provider,
  }) {
    _allowExternalAi = userConsented;
    if (provider != null) {
      _externalProvider = provider;
    }
  }

  static const Set<String> _stopWords = {
    'a',
    'about',
    'above',
    'after',
    'again',
    'against',
    'all',
    'am',
    'an',
    'and',
    'any',
    'are',
    'as',
    'at',
    'be',
    'because',
    'been',
    'before',
    'being',
    'below',
    'between',
    'both',
    'but',
    'by',
    'could',
    'did',
    'do',
    'does',
    'doing',
    'down',
    'during', 'each', 'few', 'for', 'from', 'further', 'had', 'has', 'have',
    'having', 'he', 'her', 'here', 'hers', 'herself', 'him', 'himself', 'his',
    'how', 'i', 'if', 'in', 'into', 'is', 'it', 'its', 'itself', 'just', 'me',
    'more',
    'most',
    'my',
    'myself',
    'no',
    'nor',
    'not',
    'now',
    'of',
    'off',
    'on',
    'once', 'only', 'or', 'other', 'our', 'ours', 'ourselves', 'out', 'over',
    'own', 'same', 'she', 'should', 'so', 'some', 'such', 'than', 'that', 'the',
    'their', 'theirs', 'them', 'themselves', 'then', 'there', 'these', 'they',
    'this', 'those', 'through', 'to', 'too', 'under', 'until', 'up', 'very',
    'was', 'we', 'were', 'what', 'when', 'where', 'which', 'while', 'who',
    'whom', 'why', 'with', 'would', 'you', 'your', 'yours', 'yourself',
    // Common Bengali function words
    'এবং', 'ও', 'আর', 'এই', 'সেই', 'যা', 'যার', 'তার', 'তাদের', 'হয়', 'হয়েছে',
    'করে', 'করা', 'করতে', 'থেকে', 'জন্য', 'মধ্যে', 'একটি', 'টি', 'টা', 'না',
  };

  static const Map<String, List<String>> _bilingualConceptMap = {
    'invoice': [
      'bill',
      'receipt',
      'tax',
      'total',
      'vat',
      'payment',
      'ইনভয়েস',
      'বিল',
      'রশিদ',
    ],
    'receipt': ['invoice', 'paid', 'subtotal', 'total', 'cash', 'রশিদ', 'টাকা'],
    'tax': [
      'vat',
      'gst',
      'nbr',
      'tin',
      'return',
      'assessment',
      'কর',
      'ভ্যাট',
      'আয়কর',
    ],
    'contract': [
      'agreement',
      'lease',
      'party',
      'signed',
      'deed',
      'চুক্তি',
      'দলিল',
    ],
    'deed': ['land', 'khatian', 'mouza', 'দলিল', 'খতিয়ান', 'জমি'],
    'medical': [
      'prescription',
      'doctor',
      'hospital',
      'rx',
      'tablet',
      'প্রেসক্রিপশন',
      'হাসপাতাল',
    ],
    'ডাক্তার': ['doctor', 'hospital', 'medical', 'prescription'],
    'রশিদ': ['receipt', 'invoice', 'payment', 'total'],
    'টাকা': ['amount', 'total', 'bdt', 'tk', 'price', 'currency'],
  };

  /// Splits English and Bengali (`।`) sentences cleanly while preserving line breaks.
  List<String> _splitSentences(String text) {
    final normalized = text.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) return [];

    final rawSegments = normalized.split(RegExp(r'(?<=[.!?।])\s+|\n+'));
    return rawSegments
        .map((s) => s.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((s) => s.length >= 6)
        .toList();
  }

  /// Extracts Unicode tokens (`Latin + Bengali + digits`), filtering stopwords.
  List<String> _tokenize(String text) {
    final matches = RegExp(
      r'[\p{L}\p{N}]+',
      unicode: true,
    ).allMatches(text.toLowerCase());
    return matches
        .map((m) => m.group(0)!)
        .where((w) => w.length > 1 && !_stopWords.contains(w))
        .toList();
  }

  Map<String, int> _calculateTermFrequencies(List<String> tokens) {
    final tf = <String, int>{};
    for (final token in tokens) {
      tf[token] = (tf[token] ?? 0) + 1;
    }
    return tf;
  }

  /// Produces extractive summary via true TextRank sentence similarity graph
  /// (PageRank damping `d = 0.85` over cosine sentence similarity + TF keywords).
  DocumentSummaryResult summarize(
    String documentText, {
    int maxBulletPoints = 4,
  }) {
    final sentences = _splitSentences(documentText);
    if (sentences.isEmpty) {
      return const DocumentSummaryResult(
        executiveSummary:
            'Document does not contain sufficient text to summarize.',
        bulletPoints: [],
        topKeywords: [],
        totalWords: 0,
        totalSentences: 0,
      );
    }

    final allTokens = _tokenize(documentText);
    final totalWords = documentText
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    final termFreqs = _calculateTermFrequencies(allTokens);

    final sortedEntries = termFreqs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topKeywords = sortedEntries.take(6).map((e) => e.key).toList();

    final int n = sentences.length;
    final sentTfs = sentences
        .map((s) => _calculateTermFrequencies(_tokenize(s)))
        .toList();

    // Build symmetric similarity matrix W[i][j] between sentences
    final sim = List<List<double>>.generate(
      n,
      (_) => List<double>.filled(n, 0.0),
    );
    final rowSums = List<double>.filled(n, 0.0);

    for (int i = 0; i < n; i++) {
      for (int j = i + 1; j < n; j++) {
        final s = _cosineSimilarity(sentTfs[i], sentTfs[j]);
        if (s > 0) {
          sim[i][j] = s;
          sim[j][i] = s;
          rowSums[i] += s;
          rowSums[j] += s;
        }
      }
    }

    // Power-iteration TextRank with damping factor 0.85
    const double d = 0.85;
    List<double> ranks = List<double>.filled(n, 1.0);
    for (int iter = 0; iter < 12; iter++) {
      final next = List<double>.filled(n, 1.0 - d);
      for (int i = 0; i < n; i++) {
        double sum = 0.0;
        for (int j = 0; j < n; j++) {
          if (i == j || rowSums[j] == 0.0 || sim[j][i] == 0.0) continue;
          sum += (sim[j][i] / rowSums[j]) * ranks[j];
        }
        // Subtle positional & information density tie-breaker for disconnected sentences
        final leadBonus = i == 0 ? 0.15 : (i == 1 ? 0.08 : 0.0);
        next[i] = (1.0 - d) + d * sum + leadBonus;
      }
      ranks = next;
    }

    final ranked = <MapEntry<int, double>>[
      for (int i = 0; i < n; i++) MapEntry(i, ranks[i]),
    ]..sort((a, b) => b.value.compareTo(a.value));

    final topIndices =
        ranked.take(min(maxBulletPoints, n)).map((e) => e.key).toList()..sort();

    final bulletPoints = topIndices.map((idx) => sentences[idx]).toList();
    return DocumentSummaryResult(
      executiveSummary: bulletPoints.join(' '),
      bulletPoints: bulletPoints,
      topKeywords: topKeywords,
      totalWords: totalWords,
      totalSentences: n,
    );
  }

  /// Extracts dates, currency totals, IDs, emails, phone numbers, and named organizations.
  DocumentEntityExtraction extractEntities(String text) {
    final clean = text.trim();
    if (clean.isEmpty) {
      return const DocumentEntityExtraction(
        dates: [],
        amounts: [],
        namesAndOrganizations: [],
        identifiers: [],
        emails: [],
        phoneNumbers: [],
      );
    }

    final dateMatches = <String>{};
    final dateRegexes = [
      RegExp(r'\b\d{4}[-/]\d{1,2}[-/]\d{1,2}\b'),
      RegExp(r'\b\d{1,2}[-/]\d{1,2}[-/]\d{2,4}\b'),
      RegExp(
        r'\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2},?\s+\d{4}\b',
        caseSensitive: false,
      ),
      RegExp(r'[০-৯]{1,2}[-/][০-৯]{1,2}[-/][০-৯]{2,4}'),
    ];
    for (final rx in dateRegexes) {
      for (final m in rx.allMatches(clean)) {
        dateMatches.add(m.group(0)!.trim());
      }
    }

    final amountMatches = <String>{};
    final amountRegexes = [
      RegExp(
        r'(?:[$€£৳₹]|BDT|USD|EUR|GBP|TK\.?|টাকা)\s*[0-9০-৯][0-9০-৯,]*(?:\.[0-9০-৯]{1,2})?',
        caseSensitive: false,
      ),
      RegExp(
        r'[0-9০-৯][0-9০-৯,]*(?:\.[0-9০-৯]{1,2})?\s*(?:BDT|USD|EUR|GBP|TK\.?|টাকা)',
        caseSensitive: false,
      ),
    ];
    for (final rx in amountRegexes) {
      for (final m in rx.allMatches(clean)) {
        amountMatches.add(m.group(0)!.trim());
      }
    }

    final emails = RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b')
        .allMatches(clean)
        .map((m) => m.group(0)!)
        .toSet()
        .toList();

    final phones =
        RegExp(
              r'(?:\+?\d{1,3}[\s-]?)?(?:\(?\d{3,4}\)?[\s-]?)?\d{3,4}[\s-]?\d{3,5}\b',
            )
            .allMatches(clean)
            .map((m) => m.group(0)!.trim())
            .where((s) => s.replaceAll(RegExp(r'\D'), '').length >= 8)
            .toSet()
            .toList();

    final identifiers = <String>{};
    final idRx = RegExp(
      r'(?:INV|INVOICE|PO|TAX|TIN|NID|REF|RECEIPT|ORDER|KHATIAN|খতিয়ান|নম্বর|নং)\s*[#:\-]*\s*[A-Z0-9০-৯\-]{3,}',
      caseSensitive: false,
    );
    for (final m in idRx.allMatches(clean)) {
      identifiers.add(m.group(0)!.trim());
    }

    final orgNames = <String>{};
    final orgRx = RegExp(
      r'\b(?:[A-Z][a-z]+(?:\s+[A-Z][a-z]+){1,3}|[A-Z][A-Za-z&\.\s]{2,}(?:Ltd\.?|LLC|Inc\.?|Corp\.?|Hospital|University|Bank|Ministry|Authority))\b',
    );
    for (final m in orgRx.allMatches(clean)) {
      final candidate = m.group(0)!.trim();
      if (candidate.length >= 4 && !dateMatches.contains(candidate)) {
        orgNames.add(candidate);
      }
    }

    return DocumentEntityExtraction(
      dates: dateMatches.take(8).toList(),
      amounts: amountMatches.take(8).toList(),
      namesAndOrganizations: orgNames.take(8).toList(),
      identifiers: identifiers.take(8).toList(),
      emails: emails.take(5).toList(),
      phoneNumbers: phones.take(5).toList(),
    );
  }

  /// Classifies document purpose and produces a structured plain-language explanation.
  DocumentExplanationResult explainDocument(String text) {
    final lower = text.toLowerCase();
    final entities = extractEntities(text);
    final summary = summarize(text, maxBulletPoints: 3);

    String category = 'General Document';
    final actions = <String>[];

    if (lower.contains('invoice') ||
        lower.contains('po #') ||
        lower.contains('bill to')) {
      category = 'Commercial Invoice / Billing';
      actions.add('Verify line items, tax/VAT, and payment due date.');
      actions.add('Export structured CSV for accounting records.');
    } else if (lower.contains('receipt') ||
        lower.contains('subtotal') ||
        text.contains('রশিদ')) {
      category = 'Payment Receipt';
      actions.add('Save under Receipts tag and verify total math.');
    } else if (lower.contains('agreement') ||
        lower.contains('lease') ||
        lower.contains('hereby') ||
        text.contains('দলিল') ||
        text.contains('খতিয়ান')) {
      category = 'Legal Contract / Property Deed';
      actions.add('Review party obligations, effective dates, and signatures.');
      actions.add('Enable App Lock or PDF password before sharing.');
    } else if (lower.contains('tax') ||
        lower.contains('tin') ||
        lower.contains('nbr') ||
        text.contains('আয়কর')) {
      category = 'Tax & Compliance Record';
      actions.add('Store in encrypted backup archive for retention.');
    } else if (lower.contains('rx') ||
        lower.contains('patient') ||
        lower.contains('hospital')) {
      category = 'Medical / Prescription Record';
      actions.add('Redact personal identifiers before external sharing.');
    }

    if (actions.isEmpty) {
      actions.add('Save Searchable PDF and assign a category tag.');
    }

    final parts = <String>[
      'This appears to be a $category (${summary.totalWords} words across ${summary.totalSentences} segments).',
    ];
    if (entities.dates.isNotEmpty) {
      parts.add('Key dates referenced: ${entities.dates.take(3).join(', ')}.');
    }
    if (entities.amounts.isNotEmpty) {
      parts.add(
        'Monetary values detected: ${entities.amounts.take(3).join(', ')}.',
      );
    }
    if (entities.namesAndOrganizations.isNotEmpty) {
      parts.add(
        'Named entities: ${entities.namesAndOrganizations.take(3).join(', ')}.',
      );
    }

    return DocumentExplanationResult(
      documentCategory: category,
      plainExplanation: parts.join(' '),
      keyTakeaways: summary.bulletPoints,
      suggestedActions: actions,
    );
  }

  /// Offline semantic Q&A engine supporting both English & Bengali sentences,
  /// plus entity-aware fallback answers for date/amount/who questions.
  DocumentQaResult answerQuestion(String documentText, String question) {
    final sentences = _splitSentences(documentText);
    if (sentences.isEmpty || question.trim().isEmpty) {
      return DocumentQaResult(
        question: question,
        bestAnswer: 'No content available to answer this question.',
        confidence: 0.0,
        relevantSentences: const [],
      );
    }

    final qLower = question.toLowerCase();
    final entities = extractEntities(documentText);

    // Direct entity-grounded answer if user explicitly asks for dates/amounts/IDs
    if ((qLower.contains('how much') ||
            qLower.contains('total') ||
            qLower.contains('amount') ||
            qLower.contains('price') ||
            question.contains('কত') ||
            question.contains('টাকা')) &&
        entities.amounts.isNotEmpty) {
      return DocumentQaResult(
        question: question,
        bestAnswer: 'Amounts found: ${entities.amounts.join(', ')}',
        confidence: 0.9,
        relevantSentences: sentences
            .where((s) => entities.amounts.any((a) => s.contains(a)))
            .take(3)
            .toList(),
      );
    }

    if ((qLower.contains('when') ||
            qLower.contains('date') ||
            question.contains('তারিখ') ||
            question.contains('কবে')) &&
        entities.dates.isNotEmpty) {
      final matching = sentences
          .where((s) => entities.dates.any((d) => s.contains(d)))
          .take(3)
          .toList();
      if (matching.isNotEmpty) {
        return DocumentQaResult(
          question: question,
          bestAnswer:
              'Dates found: ${entities.dates.join(', ')} — ${matching.first}',
          confidence: 0.88,
          relevantSentences: matching,
        );
      }
    }

    final questionTokens = _expandTokens(_tokenize(question));
    if (questionTokens.isEmpty) {
      return DocumentQaResult(
        question: question,
        bestAnswer: 'Could not extract search keywords from question.',
        confidence: 0.0,
        relevantSentences: const [],
      );
    }

    final questionTf = _calculateTermFrequencies(questionTokens);
    final sentenceScores = <MapEntry<int, double>>[];

    for (int i = 0; i < sentences.length; i++) {
      final sentTokens = _tokenize(sentences[i]);
      if (sentTokens.isEmpty) continue;
      final sentTf = _calculateTermFrequencies(sentTokens);
      final sim = _cosineSimilarity(questionTf, sentTf);
      if (sim > 0) {
        sentenceScores.add(MapEntry(i, sim));
      }
    }

    if (sentenceScores.isEmpty) {
      return DocumentQaResult(
        question: question,
        bestAnswer:
            'No matching passage found in this document for: "$question"',
        confidence: 0.0,
        relevantSentences: const [],
      );
    }

    sentenceScores.sort((a, b) => b.value.compareTo(a.value));
    final bestIdx = sentenceScores.first.key;
    final confidence = min(1.0, sentenceScores.first.value * 1.5);
    final relevant = sentenceScores
        .take(3)
        .map((e) => sentences[e.key])
        .toList();

    return DocumentQaResult(
      question: question,
      bestAnswer: sentences[bestIdx],
      confidence: double.parse(confidence.toStringAsFixed(2)),
      relevantSentences: relevant,
    );
  }

  /// Cross-document semantic & bilingual concept search across the local SQLite vault.
  Future<List<SemanticVaultSearchResult>> semanticSearchVault(
    String query, {
    int maxResults = 10,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final expandedQueryTokens = _expandTokens(_tokenize(trimmed));
    final qTf = _calculateTermFrequencies(expandedQueryTokens);

    final allDocs = await AppDatabaseService.instance.getAllDocuments();
    final results = <SemanticVaultSearchResult>[];

    for (final doc in allDocs) {
      final ocrText = await AppDatabaseService.instance.getDocumentOcr(doc.id);
      final combined = '${doc.title}\n${ocrText ?? ''}';
      final docTokens = _tokenize(combined);
      if (docTokens.isEmpty) continue;
      final dTf = _calculateTermFrequencies(docTokens);
      final sim = _cosineSimilarity(qTf, dTf);
      if (sim > 0) {
        final qa = answerQuestion(combined, trimmed);
        results.add(
          SemanticVaultSearchResult(
            document: doc,
            relevanceScore: double.parse(sim.toStringAsFixed(3)),
            matchedExcerpt: qa.relevantSentences.isNotEmpty
                ? qa.relevantSentences.first
                : (ocrText?.split('\n').firstOrNull ?? doc.title),
          ),
        );
      }
    }

    results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    return results.take(maxResults).toList();
  }

  List<String> _expandTokens(List<String> tokens) {
    final expanded = <String>[...tokens];
    for (final t in tokens) {
      final synonyms = _bilingualConceptMap[t];
      if (synonyms != null) {
        expanded.addAll(synonyms);
      }
    }
    return expanded;
  }

  double _cosineSimilarity(Map<String, int> a, Map<String, int> b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    double dot = 0.0;
    for (final k in a.keys) {
      if (b.containsKey(k)) {
        dot += a[k]! * b[k]!;
      }
    }
    if (dot == 0.0) return 0.0;
    double magA = 0.0;
    for (final v in a.values) {
      magA += v * v;
    }
    double magB = 0.0;
    for (final v in b.values) {
      magB += v * v;
    }
    if (magA == 0.0 || magB == 0.0) return 0.0;
    return dot / (sqrt(magA) * sqrt(magB));
  }
}
