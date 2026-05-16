class GPAData {
  final String type;
  final String value;

  const GPAData({required this.type, required this.value});
}

class GPABean {
  final String time;
  final List<GPAData> data;

  const GPABean({required this.time, required this.data});
}
