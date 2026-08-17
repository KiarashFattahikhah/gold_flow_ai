/// Fixed prediction-interval half-widths per forecast horizon, in price
/// units (e.g. USD for gold). The predicted price is shown as a range:
/// [predicted - halfWidth, predicted + halfWidth].
const Map<int, double> horizonPriceBandHalfWidth = {
  5: 2.34,
  15: 3.97,
};

/// Returns the (low, high) band around [predictedClose] for
/// [horizonMinutes], or null if no band is defined for that horizon.
({double low, double high})? priceBandFor(int horizonMinutes, double predictedClose) {
  final halfWidth = horizonPriceBandHalfWidth[horizonMinutes];
  if (halfWidth == null) return null;
  return (low: predictedClose - halfWidth, high: predictedClose + halfWidth);
}