class HomeCareProviderModel {
  final int id;
  final String name;
  final String phone;
  final String city;
  final String district;
  final String address;
  final String? description;
  final String? imageUrl;

  HomeCareProviderModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.city,
    required this.district,
    required this.address,
    required this.description,
    required this.imageUrl,
  });

  factory HomeCareProviderModel.fromJson(Map<String, dynamic> j) {
    return HomeCareProviderModel(
      id: (j['id'] ?? j['Id'] ?? 0) as int,
      name: (j['name'] ?? j['Name'] ?? '').toString(),
      phone: (j['phone'] ?? j['Phone'] ?? '').toString(),
      city: (j['city'] ?? j['City'] ?? '').toString(),
      district: (j['district'] ?? j['District'] ?? '').toString(),
      address: (j['address'] ?? j['Address'] ?? '').toString(),
      description: (j['description'] ?? j['Description'])?.toString(),
      imageUrl: (j['imageUrl'] ?? j['ImageUrl'])?.toString(),
    );
  }
}

enum HomeCareRequestStatusModel {
  pending,
  accepted,
  rejected,
  cancelled,
  completed,
}

HomeCareRequestStatusModel statusFromJson(dynamic raw) {
  if (raw is int) {
    switch (raw) {
      case 0:
        return HomeCareRequestStatusModel.pending;
      case 1:
        return HomeCareRequestStatusModel.accepted;
      case 2:
        return HomeCareRequestStatusModel.rejected;
      case 3:
        return HomeCareRequestStatusModel.cancelled;
      case 4:
        return HomeCareRequestStatusModel.completed;
    }
  }
  final s = raw?.toString().toLowerCase() ?? '';
  if (s.contains('completed')) return HomeCareRequestStatusModel.completed;
  if (s.contains('accepted')) return HomeCareRequestStatusModel.accepted;
  if (s.contains('rejected')) return HomeCareRequestStatusModel.rejected;
  if (s.contains('cancel')) return HomeCareRequestStatusModel.cancelled;
  return HomeCareRequestStatusModel.pending;
}

class HomeCareProviderRequestModel {
  final int id;
  final String userId;
  final String userFullName;
  final int addressId;
  final String addressSnapshot;
  final DateTime serviceDateUtc;
  final String timeSlot;
  final String? note;
  final String status;
  final String? statusNote;
  final DateTime createdAtUtc;
  final double? earningAmount;
  final DateTime? completedAtUtc;
  final String? assignedEmployeeName;
  final String? completionNote;

  HomeCareProviderRequestModel({
    required this.id,
    required this.userId,
    required this.userFullName,
    required this.addressId,
    required this.addressSnapshot,
    required this.serviceDateUtc,
    required this.timeSlot,
    required this.note,
    required this.status,
    required this.statusNote,
    required this.createdAtUtc,
    this.earningAmount,
    this.completedAtUtc,
    this.assignedEmployeeName,
    this.completionNote,
  });

  factory HomeCareProviderRequestModel.fromJson(Map<String, dynamic> j) {
    DateTime? parseOptDate(dynamic v) {
      if (v == null) return null;
      try { return DateTime.parse(v.toString()).toLocal(); } catch (_) { return null; }
    }
    final earnRaw = j['earningAmount'] ?? j['EarningAmount'];
    return HomeCareProviderRequestModel(
      id: (j['id'] ?? j['Id'] ?? 0) as int,
      userId: (j['userId'] ?? j['UserId'] ?? '').toString(),
      userFullName: (j['userFullName'] ?? j['UserFullName'] ?? '').toString(),
      addressId: (j['addressId'] ?? j['AddressId'] ?? 0) as int,
      addressSnapshot: (j['addressSnapshot'] ?? j['AddressSnapshot'] ?? '').toString(),
      serviceDateUtc:
          DateTime.parse((j['serviceDateUtc'] ?? j['ServiceDateUtc']).toString())
              .toLocal(),
      timeSlot: (j['timeSlot'] ?? j['TimeSlot'] ?? '').toString(),
      note: (j['note'] ?? j['Note'])?.toString(),
      status: (j['status'] ?? j['Status'] ?? 'Pending').toString(),
      statusNote: (j['statusNote'] ?? j['StatusNote'])?.toString(),
      createdAtUtc:
          DateTime.parse((j['createdAtUtc'] ?? j['CreatedAtUtc']).toString())
              .toLocal(),
      earningAmount: earnRaw == null
          ? null
          : (earnRaw is num ? earnRaw.toDouble() : double.tryParse(earnRaw.toString())),
      completedAtUtc: parseOptDate(j['completedAtUtc'] ?? j['CompletedAtUtc']),
      assignedEmployeeName:
          (j['assignedEmployeeName'] ?? j['AssignedEmployeeName'])?.toString(),
      completionNote: (j['completionNote'] ?? j['CompletionNote'])?.toString(),
    );
  }
}

class HomeCareRequestModel {
  final int id;
  final int providerId;
  final String providerName;
  final int addressId;
  final String addressSnapshot;
  final DateTime serviceDateUtc;
  final String timeSlot;
  final String? note;
  final HomeCareRequestStatusModel status;
  final DateTime createdAtUtc;
  final String? statusNote;
  final double? earningAmount;
  final DateTime? completedAtUtc;
  final String? completionNote;
  final String? assignedEmployeeName;

  HomeCareRequestModel({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.addressId,
    required this.addressSnapshot,
    required this.serviceDateUtc,
    required this.timeSlot,
    required this.note,
    required this.status,
    required this.createdAtUtc,
    this.statusNote,
    this.earningAmount,
    this.completedAtUtc,
    this.completionNote,
    this.assignedEmployeeName,
  });

  factory HomeCareRequestModel.fromJson(Map<String, dynamic> j) {
    DateTime? parseOptDate(dynamic v) {
      if (v == null) return null;
      try { return DateTime.parse(v.toString()).toLocal(); } catch (_) { return null; }
    }
    final earnRaw = j['earningAmount'] ?? j['EarningAmount'];
    return HomeCareRequestModel(
      id: (j['id'] ?? j['Id'] ?? 0) as int,
      providerId: (j['providerId'] ?? j['ProviderId'] ?? 0) as int,
      providerName:
          (j['providerName'] ?? j['ProviderName'] ?? '').toString(),
      addressId: (j['addressId'] ?? j['AddressId'] ?? 0) as int,
      addressSnapshot:
          (j['addressSnapshot'] ?? j['AddressSnapshot'] ?? '').toString(),
      serviceDateUtc:
          DateTime.parse((j['serviceDateUtc'] ?? j['ServiceDateUtc']).toString())
              .toLocal(),
      timeSlot: (j['timeSlot'] ?? j['TimeSlot'] ?? '').toString(),
      note: (j['note'] ?? j['Note'])?.toString(),
      status: statusFromJson(j['status'] ?? j['Status']),
      createdAtUtc:
          DateTime.parse((j['createdAtUtc'] ?? j['CreatedAtUtc']).toString())
              .toLocal(),
      statusNote: (j['statusNote'] ?? j['StatusNote'])?.toString(),
      earningAmount: earnRaw == null ? null : (earnRaw is num ? earnRaw.toDouble() : double.tryParse(earnRaw.toString())),
      completedAtUtc: parseOptDate(j['completedAtUtc'] ?? j['CompletedAtUtc']),
      completionNote: (j['completionNote'] ?? j['CompletionNote'])?.toString(),
      assignedEmployeeName: (j['assignedEmployeeName'] ?? j['AssignedEmployeeName'])?.toString(),
    );
  }
}

