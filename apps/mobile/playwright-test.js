// Playwright test script for Agent Deck mobile web app
const { chromium } = require('playwright');

async function testAgentDeckWeb() {
  const browser = await chromium.launch({ headless: false });
  const page = await browser.newPage();

  console.log('🌐 Navigating to Agent Deck web app...');
  await page.goto('http://localhost:8081');

  // Wait for the app to load
  await page.waitForTimeout(3000);

  // Take a screenshot
  await page.screenshot({ path: 'screenshot-initial.png', fullPage: true });
  console.log('📸 Screenshot saved: screenshot-initial.png');

  // Get page content
  const content = await page.content();
  console.log('\n📄 Page HTML length:', content.length);

  // Check for key elements
  const bodyText = await page.textContent('body');
  console.log('\n📝 Page text content (first 500 chars):');
  console.log(bodyText?.substring(0, 500) || 'No content found');

  // Check for agent cards
  const agentCards = await page.$$('[data-testid="agent-card"]');
  console.log('\n🤖 Agent cards found:', agentCards.length);

  // Check for connection status
  const connectionText = await page.textContent('body');
  if (connectionText?.includes('Connecting') || connectionText?.includes('Connected') || connectionText?.includes('Disconnected')) {
    console.log('🔌 Connection status visible in UI');
  }

  // Try clicking on an agent card if available
  if (agentCards.length > 0) {
    console.log('\n👆 Clicking on first agent card...');
    await agentCards[0].click();
    await page.waitForTimeout(1000);
    await page.screenshot({ path: 'screenshot-after-click.png', fullPage: true });
    console.log('📸 Screenshot saved: screenshot-after-click.png');
  }

  // Keep browser open for inspection
  console.log('\n✅ Test complete. Browser will close in 30 seconds...');
  await page.waitForTimeout(30000);

  await browser.close();
}

testAgentDeckWeb().catch(console.error);
