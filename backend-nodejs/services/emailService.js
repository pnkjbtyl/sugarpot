const nodemailer = require('nodemailer');

// Validate required email environment variables
const requiredEnvVars = ['MAIL_HOST', 'MAIL_PORT', 'MAIL_USERNAME', 'MAIL_PASSWORD', 'MAIL_FROM_ADDRESS'];
const missingVars = requiredEnvVars.filter(varName => !process.env[varName]);

if (missingVars.length > 0) {
  console.error('❌ Missing required email environment variables:', missingVars.join(', '));
  console.error('Please ensure all MAIL_* variables are set in your .env file');
}

// Create reusable transporter object using SMTP transport
// All values must come from .env file - no hardcoded fallbacks
const transporter = nodemailer.createTransport({
  host: process.env.MAIL_HOST,
  port: parseInt(process.env.MAIL_PORT),
  secure: false, // true for 465, false for other ports (587 uses STARTTLS)
  auth: {
    user: process.env.MAIL_USERNAME,
    pass: process.env.MAIL_PASSWORD,
  },
  // Use MAIL_EHLO_DOMAIN as local domain for EHLO command
  name: process.env.MAIL_EHLO_DOMAIN || process.env.MAIL_HOST,
  tls: {
    // Do not fail on invalid certs
    rejectUnauthorized: false,
    minVersion: 'TLSv1.2'
  },
  requireTLS: true,
  connectionTimeout: 10000, // 10 seconds
  greetingTimeout: 10000,
  socketTimeout: 10000,
  debug: process.env.NODE_ENV === 'development' // Enable debug in development
});

// Verify connection configuration
transporter.verify(function (error, success) {
  if (error) {
    console.log('Email service configuration error:', error);
  } else {
    console.log('Email service is ready to send messages');
  }
});

/**
 * Send OTP email
 * @param {string} email - Recipient email address
 * @param {string} otpCode - 6-digit OTP code
 * @returns {Promise<Object>} - Email send result
 */
async function sendOTPEmail(email, otpCode) {
  // Validate required env variables before sending
  if (!process.env.MAIL_FROM_ADDRESS) {
    throw new Error('MAIL_FROM_ADDRESS is not set in environment variables');
  }

  const mailOptions = {
    from: `"${process.env.MAIL_FROM_NAME || 'SugarPot'}" <${process.env.MAIL_FROM_ADDRESS}>`,
    to: email,
    subject: 'Your SugarPot Verification Code',
    html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
          }
          .container {
            background-color: #ffffff;
            border-radius: 10px;
            padding: 30px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
          }
          .header {
            text-align: center;
            margin-bottom: 30px;
          }
          .logo {
            font-size: 32px;
            font-weight: bold;
            color: #a872be;
            margin-bottom: 10px;
          }
          .otp-box {
            background-color: #f8f9fa;
            border: 2px dashed #a872be;
            border-radius: 8px;
            padding: 20px;
            text-align: center;
            margin: 30px 0;
          }
          .otp-code {
            font-size: 36px;
            font-weight: bold;
            color: #a872be;
            letter-spacing: 8px;
            font-family: 'Courier New', monospace;
          }
          .footer {
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #eee;
            font-size: 12px;
            color: #666;
            text-align: center;
          }
          .warning {
            background-color: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 12px;
            margin: 20px 0;
            border-radius: 4px;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <div class="logo"><span style="color: #a872be;">❤</span> SugarPot</div>
            <h2>Email Verification</h2>
          </div>
          
          <p>Hello,</p>
          
          <p>Thank you for using SugarPot! Please use the verification code below to move ahead:</p>
          
          <div class="otp-box">
            <div class="otp-code">${otpCode}</div>
          </div>
          
          <div class="warning">
            <strong>⚠️ Security Notice:</strong> This code will expire in 1 hour. Do not share this code with anyone.
          </div>
          
          <p>If you didn't request this code, please ignore this email.</p>
          
          <p>Best regards,<br>The SugarPot Team</p>
          
          <div class="footer">
            <p>This is an automated message. Please do not reply to this email.</p>
            <p>&copy; ${new Date().getFullYear()} SugarPot. All rights reserved.</p>
          </div>
        </div>
      </body>
      </html>
    `,
    text: `
      SugarPot Email Verification
      
      Hello,
      
      Thank you for signing up for SugarPot! Please use the verification code below to complete your registration:
      
      Verification Code: ${otpCode}
      
      This code will expire in 1 hour. Do not share this code with anyone.
      
      If you didn't request this code, please ignore this email.
      
      Best regards,
      The SugarPot Team
    `
  };

  try {
    const info = await transporter.sendMail(mailOptions);
    console.log('OTP email sent successfully:', info.messageId);
    console.log('Email details:', {
      accepted: info.accepted,
      rejected: info.rejected,
      pending: info.pending,
      response: info.response
    });
    return {
      success: true,
      messageId: info.messageId,
      accepted: info.accepted,
      rejected: info.rejected,
      response: info.response
    };
  } catch (error) {
    console.error('Error sending OTP email:', error);
    console.error('Error details:', {
      message: error.message,
      code: error.code,
      command: error.command,
      response: error.response,
      responseCode: error.responseCode
    });
    throw error;
  }
}

module.exports = {
  sendOTPEmail,
  transporter
};
