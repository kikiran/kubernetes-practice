const express = require('express');
const os = require('os');
const app = express();
const PORT = process.env.PORT || 3000;
const VERSION = process.env.APP_VERSION || 'v1';
const COLOR = process.env.APP_COLOR || 'blue';

// Middleware
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
    res.status(200).json({
        status: 'healthy',
        version: VERSION,
        color: COLOR,
        hostname: os.hostname(),
        timestamp: new Date().toISOString()
    });
});

// Readiness probe
app.get('/ready', (req, res) => {
    res.status(200).json({
        ready: true,
        version: VERSION
    });
});

// Main endpoint with version info
app.get('/', (req, res) => {
    res.json({
        message: `Hello from ${COLOR} deployment!`,
        version: VERSION,
        color: COLOR,
        hostname: os.hostname(),
        environment: process.env.NODE_ENV || 'production',
        timestamp: new Date().toISOString(),
        podIP: process.env.POD_IP || 'unknown',
        nodeName: process.env.NODE_NAME || 'unknown'
    });
});

// API endpoint
app.get('/api/info', (req, res) => {
    res.json({
        application: 'deployment-demo',
        version: VERSION,
        deployment_type: COLOR,
        details: {
            hostname: os.hostname(),
            platform: os.platform(),
            arch: os.arch(),
            uptime: process.uptime(),
            memory: process.memoryUsage()
        }
    });
});

// Version endpoint (for testing different versions)
app.get('/version', (req, res) => {
    res.json({
        version: VERSION,
        color: COLOR,
        features: getVersionFeatures(VERSION)
    });
});

function getVersionFeatures(version) {
    const features = {
        'v1': ['Basic functionality', 'Health checks'],
        'v2': ['Basic functionality', 'Health checks', 'Enhanced API', 'Better performance'],
        'v3': ['All v2 features', 'Advanced analytics', 'AI-powered recommendations']
    };
    return features[version] || features['v1'];
}

// Error endpoint (for testing rollback scenarios)
app.get('/error', (req, res) => {
    if (VERSION === 'v2-buggy') {
        res.status(500).json({ error: 'This version has a critical bug!' });
    } else {
        res.status(200).json({ message: 'No errors in this version' });
    }
});

// Simulate slow response (for canary testing)
app.get('/slow', async (req, res) => {
    const delay = VERSION === 'v2' ? 100 : 2000; // v2 is faster
    await new Promise(resolve => setTimeout(resolve, delay));
    res.json({ 
        message: 'Response completed',
        version: VERSION,
        delay: delay 
    });
});

app.listen(PORT, () => {
    console.log(`🚀 Server started on port ${PORT}`);
    console.log(`📦 Version: ${VERSION}`);
    console.log(`🎨 Color: ${COLOR}`);
    console.log(`🖥️  Hostname: ${os.hostname()}`);
    console.log(`⏰ Started at: ${new Date().toISOString()}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully...');
    server.close(() => {
        console.log('Server closed');
        process.exit(0);
    });
});
