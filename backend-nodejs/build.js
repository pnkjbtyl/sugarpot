const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const distDir = path.join(__dirname, 'dist');

// Clean dist folder
if (fs.existsSync(distDir)) {
  fs.rmSync(distDir, { recursive: true, force: true });
}
fs.mkdirSync(distDir, { recursive: true });

console.log('📦 Building production package...\n');

// Files and folders to copy
const filesToCopy = [
  'server.js',
  'package.json',
  'package-lock.json',
  '.env',
  'README.md'
];

const foldersToCopy = [
  'routes',
  'models',
  'middleware',
  'services',
  'sockets',
  'scripts'
];

// Copy files
console.log('📄 Copying files...');
filesToCopy.forEach(file => {
  const src = path.join(__dirname, file);
  const dest = path.join(distDir, file);
  if (fs.existsSync(src)) {
    fs.copyFileSync(src, dest);
    console.log(`  ✓ ${file}`);
  } else {
    console.log(`  ⚠ ${file} not found (skipping)`);
  }
});

// Copy folders
console.log('\n📁 Copying folders...');
foldersToCopy.forEach(folder => {
  const src = path.join(__dirname, folder);
  const dest = path.join(distDir, folder);
  if (fs.existsSync(src)) {
    copyRecursiveSync(src, dest);
    console.log(`  ✓ ${folder}/`);
  } else {
    console.log(`  ⚠ ${folder}/ not found (skipping)`);
  }
});

// Create uploads directory structure
console.log('\n📂 Creating uploads directories...');
const uploadsDirs = [
  'uploads/user-images/thumbnails',
  'uploads/gallery/public/thumbnails',
  'uploads/gallery/locked/thumbnails',
  'uploads/chat-media'
];

uploadsDirs.forEach(dir => {
  const fullPath = path.join(distDir, dir);
  fs.mkdirSync(fullPath, { recursive: true });
  console.log(`  ✓ ${dir}`);
});

// Install production dependencies
console.log('\n📥 Installing production dependencies...');
try {
  process.chdir(distDir);
  execSync('npm install --omit=dev', { stdio: 'inherit' });
  console.log('  ✓ Dependencies installed');
} catch (error) {
  console.error('  ✗ Failed to install dependencies:', error.message);
  process.exit(1);
}

// Create .gitignore for dist
const gitignoreContent = `node_modules/
uploads/*
!.gitkeep
*.log
.env
`;
fs.writeFileSync(path.join(distDir, '.gitignore'), gitignoreContent);

// Create .gitkeep for uploads directories
uploadsDirs.forEach(dir => {
  const gitkeepPath = path.join(distDir, dir, '.gitkeep');
  fs.writeFileSync(gitkeepPath, '');
});

console.log('\n✅ Build complete!');
console.log(`📦 Production package ready in: ${distDir}`);
console.log('\n📋 Next steps:');
console.log('  1. Review .env file in dist folder');
console.log('  2. Compress dist folder: zip -r backend-production.zip dist/');
console.log('  3. Upload to cPanel and extract');
console.log('  4. Set up Node.js app pointing to dist/server.js');

// Helper function to copy directories recursively
function copyRecursiveSync(src, dest) {
  const exists = fs.existsSync(src);
  const stats = exists && fs.statSync(src);
  const isDirectory = exists && stats.isDirectory();

  if (isDirectory) {
    if (!fs.existsSync(dest)) {
      fs.mkdirSync(dest, { recursive: true });
    }
    fs.readdirSync(src).forEach(childItemName => {
      copyRecursiveSync(
        path.join(src, childItemName),
        path.join(dest, childItemName)
      );
    });
  } else {
    fs.copyFileSync(src, dest);
  }
}
