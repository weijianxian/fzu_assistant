/// Third-party services are opt-in, independently for each feature.
enum FeatureAccess {
  tip,
  allow,
  hide;

  static FeatureAccess parse(String? value) =>
      values.firstWhere((entry) => entry.name == value, orElse: () => tip);
}
