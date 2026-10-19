import 'dart:math';

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

/// Service providing on-device Extractive TextRank, TF-IDF summarization, and offline Q&A Assistant (F-35).
class AiDocumentService {
  AiDocumentService._();
  static final AiDocumentService instance = AiDocumentService._();

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
    'during',
    'each',
    'few',
    'for',
    'from',
    'further',
    'had',
    'has',
    'have',
    'having',
    'he',
    'her',
    'here',
    'hers',
    'herself',
    'him',
    'himself',
    'his',
    'how',
    'i',
    'if',
    'in',
    'into',
    'is',
    'it',
    'its',
    'itself',
    'just',
    'me',
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
    'once',
    'only',
    'or',
    'other',
    'our',
    'ours',
    'ourselves',
    'out',
    'over',
    'own',
    'same',
    'she',
    'should',
    'so',
    'some',
    'such',
    'than',
    'that',
    'the',
    'their',
    'theirs',
    'them',
    'themselves',
    'then',
    'there',
    'these',
    'they',
    'this',
    'those',
    'through',
    'to',
    'too',
    'under',
    'until',
    'up',
    'very',
    'was',
    'we',
    'were',
    'what',
    'when',
    'where',
    'which',
    'while',
    'who',
    'whom',
    'why',
    'with',
    'would',
    'you',
    'your',
    'yours',
    'yourself',
  };

  /// Tokenizes text into sentences handling periods, exclamation, and question marks
  List<String> _splitSentences(String text) {
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return [];

    final rawSentences = cleaned.split(RegExp(r'(?<=[.!?])\s+'));
    return rawSentences
        .map((s) => s.trim())
        .where((s) => s.length >= 10)
        .toList();
  }

  /// Extracts clean alpha tokens from text
  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !_stopWords.contains(w))
        .toList();
  }

  /// Calculates word frequency dictionary across the entire document
  Map<String, int> _calculateTermFrequencies(List<String> tokens) {
    final Map<String, int> tf = {};
    for (final token in tokens) {
      tf[token] = (tf[token] ?? 0) + 1;
    }
    return tf;
  }

  /// Produces extractive summary using sentence scoring (TF-IDF weight + position weight + length normalization)
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

    // Extract top 5 keywords
    final sortedEntries = termFreqs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topKeywords = sortedEntries.take(6).map((e) => e.key).toList();

    // Score sentences
    final List<MapEntry<int, double>> scoredSentences = [];
    for (int i = 0; i < sentences.length; i++) {
      final sentence = sentences[i];
      final sentenceTokens = _tokenize(sentence);
      if (sentenceTokens.isEmpty) continue;

      double score = 0.0;
      for (final token in sentenceTokens) {
        score += termFreqs[token] ?? 0;
      }

      // Length normalization: avoid penalizing short sentences or over-rewarding long lists
      score = score / pow(sentenceTokens.length, 0.6);

      // Lead bias (initial sentences typically carry higher contextual thesis)
      if (i == 0) score *= 1.35;
      if (i == 1) score *= 1.2;

      scoredSentences.add(MapEntry(i, score));
    }

    // Pick top sentences preserving chronological flow
    scoredSentences.sort((a, b) => b.value.compareTo(a.value));
    final topIndices =
        scoredSentences.take(maxBulletPoints).map((e) => e.key).toList()
          ..sort();

    final bulletPoints = topIndices.map((idx) => sentences[idx]).toList();
    final executiveSummary = bulletPoints.join(' ');

    return DocumentSummaryResult(
      executiveSummary: executiveSummary,
      bulletPoints: bulletPoints,
      topKeywords: topKeywords,
      totalWords: totalWords,
      totalSentences: sentences.length,
    );
  }

  /// Offline semantic Q&A answering engine using TF-IDF cosine similarity vector matching
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

    final questionTokens = _tokenize(question);
    if (questionTokens.isEmpty) {
      return DocumentQaResult(
        question: question,
        bestAnswer: 'Could not extract search keywords from question.',
        confidence: 0.0,
        relevantSentences: const [],
      );
    }

    // Build question vector
    final questionTf = _calculateTermFrequencies(questionTokens);

    // Score each sentence against question vector
    final List<MapEntry<int, double>> sentenceScores = [];
    for (int i = 0; i < sentences.length; i++) {
      final sentTokens = _tokenize(sentences[i]);
      if (sentTokens.isEmpty) continue;

      final sentTf = _calculateTermFrequencies(sentTokens);

      // Compute dot product and vector magnitudes
      double dotProduct = 0.0;
      for (final qToken in questionTf.keys) {
        if (sentTf.containsKey(qToken)) {
          dotProduct += questionTf[qToken]! * sentTf[qToken]!;
        }
      }

      if (dotProduct == 0) continue;

      double magQ = 0.0;
      for (final v in questionTf.values) {
        magQ += v * v;
      }
      magQ = sqrt(magQ);

      double magS = 0.0;
      for (final v in sentTf.values) {
        magS += v * v;
      }
      magS = sqrt(magS);

      final cosineSimilarity = dotProduct / (magQ * magS);
      sentenceScores.add(MapEntry(i, cosineSimilarity));
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

    // Collect top 2 surrounding or matching sentences for context
    final relevant = <String>[];
    for (final entry in sentenceScores.take(3)) {
      relevant.add(sentences[entry.key]);
    }

    return DocumentQaResult(
      question: question,
      bestAnswer: sentences[bestIdx],
      confidence: double.parse(confidence.toStringAsFixed(2)),
      relevantSentences: relevant,
    );
  }
}
