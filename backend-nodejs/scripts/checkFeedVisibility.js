/**
 * Diagnostic: why is [targetName] not visible in [viewerName]'s feed?
 * Usage: node scripts/checkFeedVisibility.js [viewerName] [targetName]
 * Example: node scripts/checkFeedVisibility.js "Varsha" "Pankaj Singh"
 */
require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../models/User');
const Match = require('../models/Match');

function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

async function main() {
  const viewerName = process.argv[2] || 'Varsha';
  const targetName = process.argv[3] || 'Pankaj Singh';

  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/sugarpot');

  const viewer = await User.findOne({ name: new RegExp(viewerName, 'i') }).lean();
  const target = await User.findOne({ name: new RegExp(targetName, 'i') }).lean();

  if (!viewer) {
    console.log(`Viewer not found: "${viewerName}"`);
    process.exit(1);
  }
  if (!target) {
    console.log(`Target not found: "${targetName}"`);
    process.exit(1);
  }

  const viewerId = viewer._id.toString();
  const targetId = target._id.toString();

  console.log('\n=== Feed visibility check ===');
  console.log(`Viewer: ${viewer.name} (${viewerId})`);
  console.log(`Target: ${target.name} (${targetId})\n`);

  const reasons = [];

  // 1. Self
  if (viewerId === targetId) {
    reasons.push('Target is the same user as viewer (self).');
  }

  // 2. Excluded by existing match (nudge / matched / unmatched)
  const existingMatches = await Match.find({
    $or: [{ user1: viewerId }, { user2: viewerId }],
    status: { $in: ['nudge', 'matched', 'unmatched'] },
  });
  const excludedIds = existingMatches.map(m => 
    m.user1.toString() === viewerId ? m.user2.toString() : m.user1.toString()
  );
  if (excludedIds.includes(targetId)) {
    const match = existingMatches.find(m => 
      m.user1.toString() === targetId || m.user2.toString() === targetId
    );
    reasons.push(`Already has interaction with target: status="${match?.status}" (nudge = heart request, matched = match, unmatched = passed).`);
  }

  // 3. Onboarding
  if (!target.isOnboardingComplete) {
    reasons.push('Target has not completed onboarding (isOnboardingComplete is false).');
  }

  // 4. Profile hidden
  if (target.isProfileHidden) {
    reasons.push('Target profile is hidden (isProfileHidden is true).');
  }

  // 5. Gender preference
  const interestedIn = viewer.preferences?.interestedIn || ['male', 'female', 'other'];
  const targetGender = target.gender;
  if (targetGender && interestedIn.length > 0 && !interestedIn.includes(targetGender)) {
    reasons.push(`Viewer's interestedIn (${JSON.stringify(interestedIn)}) does not include target's gender (${targetGender}).`);
  }

  // 6. Location
  if (!target.location?.latitude || !target.location?.longitude) {
    reasons.push('Target has no location set (location.latitude/longitude missing).');
  }
  if (!viewer.location?.latitude || !viewer.location?.longitude) {
    reasons.push('Viewer has no location set - feed would return 400.');
  }

  // 7. Age
  const minAge = viewer.preferences?.minAge ?? 18;
  const maxAge = viewer.preferences?.maxAge ?? 100;
  let targetAge = null;
  if (target.dateOfBirth) {
    const now = new Date();
    const birth = new Date(target.dateOfBirth);
    targetAge = now.getFullYear() - birth.getFullYear();
    const monthDiff = now.getMonth() - birth.getMonth();
    if (monthDiff < 0 || (monthDiff === 0 && now.getDate() < birth.getDate())) targetAge--;
  } else {
    reasons.push('Target has no dateOfBirth set.');
  }
  if (targetAge != null && (targetAge < minAge || targetAge > maxAge)) {
    reasons.push(`Target age (${targetAge}) is outside viewer's range (${minAge}-${maxAge}).`);
  }

  // 8. Distance
  const maxDistance = viewer.preferences?.maxDistance ?? 50;
  if (viewer.location?.latitude != null && target.location?.latitude != null) {
    const distance = calculateDistance(
      viewer.location.latitude, viewer.location.longitude,
      target.location.latitude, target.location.longitude
    );
    if (distance > maxDistance) {
      reasons.push(`Target is ${Math.round(distance * 10) / 10} km away; viewer maxDistance is ${maxDistance} km.`);
    }
    console.log(`Distance: ${Math.round(distance * 10) / 10} km (viewer max: ${maxDistance} km)`);
  }

  // Summary
  if (reasons.length === 0) {
    console.log('No exclusion reason found. Target should appear in viewer feed (if not, check sort/limit).');
  } else {
    console.log('Reasons target is NOT in feed:');
    reasons.forEach((r, i) => console.log(`  ${i + 1}. ${r}`));
  }

  console.log('\nViewer prefs:', { maxDistance, minAge, maxAge, interestedIn });
  console.log('Target:', {
    gender: target.gender,
    age: targetAge,
    isOnboardingComplete: target.isOnboardingComplete,
    isProfileHidden: target.isProfileHidden,
    hasLocation: !!(target.location?.latitude && target.location?.longitude),
  });

  await mongoose.disconnect();
  process.exit(0);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
