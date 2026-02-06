import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_issue_reporting/citizen/report_issue.dart';

void main() {
  test('issueCategories contains all required categories', () {
    expect(issueCategories, contains('Pothole'));
    expect(issueCategories, contains('Broken Streetlight'));
    expect(issueCategories, contains('Overflowing Garbage Bin'));
    expect(issueCategories, contains('Drainage Blockage'));
    expect(issueCategories, contains('Unsafe Public Space'));
    expect(issueCategories, contains('Damaged Infrastructure'));
    expect(issueCategories.length, 6);
  });
}
