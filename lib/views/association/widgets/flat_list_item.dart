import 'package:flutter/material.dart';
import 'package:finalrep_app/models/athlete_group.dart';
import 'package:finalrep_app/models/competition_group.dart';
import 'package:finalrep_app/models/association_member.dart';

abstract class FlatListItem {}

class FlatHeaderItem extends FlatListItem {
  final String key;
  final String title;
  final int level;
  final TextStyle? textStyle;
  final Color? textColor;
  final String? countText;
  final List<AthleteGroup>? athleteGroups;

  FlatHeaderItem({
    required this.key,
    required this.title,
    required this.level,
    this.textStyle,
    this.textColor,
    this.countText,
    this.athleteGroups,
  });
}

class FlatAthleteGroupCardItem extends FlatListItem {
  final AthleteGroup athleteGroup;
  FlatAthleteGroupCardItem({required this.athleteGroup});
}

class FlatReorderableGroupItem extends FlatListItem {
  final String genderKey;
  final List<AthleteGroup> athleteGroups;
  FlatReorderableGroupItem({
    required this.genderKey,
    required this.athleteGroups,
  });
}

class FlatCompGroupCardItem extends FlatListItem {
  final CompetitionGroup compGroup;
  FlatCompGroupCardItem({required this.compGroup});
}

class FlatMemberCardItem extends FlatListItem {
  final AssociationMember member;
  FlatMemberCardItem({required this.member});
}

class FlatSportFormatItem extends FlatListItem {
  final String sport;
  final String format;
  final List<String> disciplines;
  final bool isAppliedShared;
  final String? owningAssociationName;

  FlatSportFormatItem({
    required this.sport,
    required this.format,
    required this.disciplines,
    required this.isAppliedShared,
    this.owningAssociationName,
  });
}

class FlatRulebookItem extends FlatListItem {
  final String sport;
  final String? format;
  final String rulebookUrl;
  final bool isAppliedShared;
  final String? owningAssociationName;
  final String? owningAssociationId;
  final bool hasAppliedShared;

  FlatRulebookItem({
    required this.sport,
    this.format,
    required this.rulebookUrl,
    required this.isAppliedShared,
    this.owningAssociationName,
    this.owningAssociationId,
    this.hasAppliedShared = false,
  });
}

