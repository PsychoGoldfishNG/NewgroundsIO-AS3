const fs = require('fs');
const path = require('path');
const AdmZip = require('adm-zip');

const rootDir = path.resolve(__dirname, '..');
const buildDir = path.join(rootDir, 'build');
const outputZip = path.join(rootDir, 'NGIO.zip');

if (!fs.existsSync(buildDir)) {
  console.error(`Build directory not found: ${buildDir}`);
  process.exit(1);
}

const zip = new AdmZip();

// Recursively add files from build directory, excluding .swf files
function addFilesRecursive(zip, dir, baseDir = '') {
  const files = fs.readdirSync(dir);
  
  files.forEach(file => {
    const filePath = path.join(dir, file);
    const relPath = baseDir ? path.join(baseDir, file) : file;
    const stat = fs.statSync(filePath);
    
    if (stat.isDirectory()) {
      addFilesRecursive(zip, filePath, relPath);
    } else if (!file.endsWith('.swf')) {
      zip.addFile(relPath.replace(/\\/g, '/'), fs.readFileSync(filePath));
    }
  });
}

addFilesRecursive(zip, buildDir);
zip.writeZip(outputZip);
console.log(`Created NGIO.zip (${fs.statSync(outputZip).size} bytes)`);
