import '../../../services/sound_analysis/sound_analysis_models.dart';

String diarySoundLabel(String category) => switch (category) {
      OpenNoiseCategory.loudConversation => 'Laute Stimmen',
      OpenNoiseCategory.shoutingOrDispute => 'Laute Rufe oder Stimmen',
      OpenNoiseCategory.partyOrMusicWithPeople => 'Musik und Stimmen',
      OpenNoiseCategory.televisionOrMusic => 'Fernsehen oder Musik',
      OpenNoiseCategory.drilling => 'Bohren',
      OpenNoiseCategory.hammering => 'Hämmern',
      OpenNoiseCategory.sawing => 'Sägen',
      OpenNoiseCategory.constructionOther => 'Baugeräusche',
      OpenNoiseCategory.furnitureMovement => 'Möbelbewegung',
      OpenNoiseCategory.footstepsOrImpactNoise => 'Schritte oder Stöße',
      OpenNoiseCategory.doorOrImpact => 'Tür oder Stoß',
      OpenNoiseCategory.householdAppliance => 'Haushaltsgerät',
      OpenNoiseCategory.roadTraffic => 'Straßenverkehr',
      OpenNoiseCategory.animals => 'Tiergeräusche',
      _ => 'Unbekanntes Geräusch',
    };
