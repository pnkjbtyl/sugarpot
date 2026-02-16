const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const Report = require('../models/Report');
const { authenticateToken } = require('../middleware/auth');

// Report a user
router.post('/', authenticateToken, async (req, res) => {
  try {
    const { reportedUserId, reason, description } = req.body;

    if (!reportedUserId || !reason) {
      return res.status(400).json({ message: 'Reported user ID and reason are required' });
    }

    // Check if user already reported this user
    const existingReport = await Report.findOne({
      reporterId: req.userId,
      reportedUserId: reportedUserId
    });

    if (existingReport) {
      // Update existing report
      existingReport.reason = reason;
      existingReport.description = description || '';
      existingReport.status = 'pending';
      existingReport.reviewedBy = null;
      existingReport.reviewedAt = null;
      await existingReport.save();
      return res.json({ message: 'Report updated successfully', report: existingReport });
    }

    // Create new report
    const report = new Report({
      reporterId: req.userId,
      reportedUserId: reportedUserId,
      reason: reason,
      description: description || ''
    });

    await report.save();
    res.json({ message: 'User reported successfully', report: report });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;
