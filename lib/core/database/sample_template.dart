/// Generic starter template. Banks word their SMS differently, so these
/// regexes are a starting point to tune in Setup > Parsing templates.
class SampleTemplate {
  static const name = 'Generic bank (sample - edit for your bank)';
  static const credit = 'credited,received,deposited,credit';
  static const debit = 'transferred,debited,withdrawn,paid,purchase,debit';
  static const amount = r"(?:ETB|Birr|USD)\s*([\d,]+(?:\.\d+)?)";
  static const balance = r"balance[^\d]{0,25}([\d,]+(?:\.\d+)?)";
  static const reference =
      r"\b(?:ref(?:erence)?|txn|trx|id)\b[^A-Za-z0-9]{0,5}([A-Za-z0-9]{6,})";
  static const from =
      r"\bfrom\s+(?!your\b|my\b|account\b|acc\b|a/c\b)([A-Za-z][A-Za-z .'-]{1,40}?)(?=\s+(?:to|on|at|with|ref|reference|account|acc|txn|via)\b|[.,;(]|$)";
  static const to =
      r"\bto\s+(?!your\b|my\b|account\b|acc\b|a/c\b)([A-Za-z][A-Za-z .'-]{1,40}?)(?=\s+(?:from|on|at|with|ref|reference|account|acc|txn|via)\b|[.,;(]|$)";
  static const counterpartyAccount =
      r"(?:to|from)\s+[A-Za-z .'-]{0,40}?(?:acc(?:ount)?|a/c)[^\dxX*]{0,8}([\dxX*]{4,})";
  static const serviceCharge =
      r"(?:service\s*(?:charge|fee)|charge|fee)[^\d]{0,20}([\d,]+(?:\.\d+)?)";
}
