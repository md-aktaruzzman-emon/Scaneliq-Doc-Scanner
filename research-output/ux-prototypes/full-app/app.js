/* ==========================================================================
   SCANELIQ — FULL APPLICATION STATE & INTERACTION CONTROLLER (CONCEPT A)
   Synchronizes Light (Gallery Alabaster) & Dark (Carbon Studio) Viewports
   ========================================================================== */

window.App = {
  state: {
    screen: 'home',         // 'home' | 'search' | 'camera' | 'editor' | 'viewer' | 'folders' | 'pdf-suite' | 'ocr-ai' | 'settings' | 'onboarding'
    pdfSubTool: null,       // null | 'merge' | 'split' | 'compress' | 'sign' | 'protect' | 'receipt' | 'card' | 'countcam'
    homeScope: 'recent',    // 'recent' | 'starred' | 'folders'
    selectMode: false,
    selectedIds: ['lease', 'bangla'],
    searchQuery: '',
    liveSearch: 'Lease',
    camAuto: true,
    camFlash: false,
    camMode: 'doc',         // 'doc' | 'batch' | 'id' | 'book' | 'receipt' | 'qr'
    capturedPages: 4,
    draftTitle: 'Tax Return FY2026 — Draft',
    activeFilter: 'Magic Color',
    editorTab: 'filters',   // 'crop' | 'filters' | 'enhance' | 'organize'
    activeDocId: 'lease',
    activeFolder: null,
    ocrTab: 'ocr',          // 'ocr' | 'bangla' | 'translate' | 'ai'
    bnAsciiDigits: false,
    settingsSub: null,      // null | 'lock' | 'backup'
    pinInput: '12',
    pinCount: 8,
    activeModal: null,      // null | 'import' | 'share' | 'rename' | 'new-folder' | 'cam-settings' | 'pro' | 'doc-sheet'
    modalDocId: 'lease',
    toastMsg: null,
    viewMode: 'dual'        // 'dual' | 'light' | 'dark'
  },

  init() {
    const params = new URLSearchParams(window.location.search);
    if (params.get('screen')) this.state.screen = params.get('screen');
    if (params.get('sub')) this.state.pdfSubTool = params.get('sub');
    if (params.get('ocr')) this.state.ocrTab = params.get('ocr');
    if (params.get('settings')) this.state.settingsSub = params.get('settings');
    if (params.get('editor')) this.state.editorTab = params.get('editor');
    if (params.get('modal')) this.state.activeModal = params.get('modal');
    if (params.get('doc')) this.state.activeDocId = params.get('doc');
    this.render();
  },

  go(screen, subTool = null) {
    this.state.screen = screen;
    if (screen === 'pdf-suite') {
      this.state.pdfSubTool = subTool;
    } else if (subTool === null && screen !== 'settings') {
      this.state.pdfSubTool = null;
      this.state.settingsSub = null;
    }
    this.state.activeModal = null;
    this.render();
  },

  setViewMode(mode) {
    this.state.viewMode = mode;
    const stage = document.getElementById('stage-wrap');
    const colLight = document.getElementById('col-light');
    const colDark = document.getElementById('col-dark');
    if (stage && colLight && colDark) {
      colLight.style.display = (mode === 'dark') ? 'none' : 'flex';
      colDark.style.display = (mode === 'light') ? 'none' : 'flex';
    }
    document.querySelectorAll('[data-view-btn]').forEach(btn => {
      btn.classList.toggle('active', btn.getAttribute('data-view-btn') === mode);
    });
  },

  toggleSingleTheme() {
    if (this.state.viewMode === 'light') {
      this.setViewMode('dark');
      this.toast('Switched single viewport to Carbon Studio (Dark)');
    } else if (this.state.viewMode === 'dark') {
      this.setViewMode('light');
      this.toast('Switched single viewport to Gallery Alabaster (Light)');
    } else {
      this.toast('Both Gallery Alabaster & Carbon Studio are visible side-by-side');
    }
  },

  setHomeScope(scope) {
    this.state.homeScope = scope;
    this.render();
  },

  toggleSelectMode() {
    this.state.selectMode = !this.state.selectMode;
    this.render();
  },

  toggleSelectDoc(id) {
    const idx = this.state.selectedIds.indexOf(id);
    if (idx >= 0) {
      this.state.selectedIds.splice(idx, 1);
    } else {
      this.state.selectedIds.push(id);
    }
    this.render();
  },

  selectAllDocs() {
    this.state.selectedIds = window.ScaneliqScreens.documents.map(d => d.id);
    this.render();
  },

  openDoc(id) {
    this.state.activeDocId = id;
    this.state.screen = 'viewer';
    this.state.activeModal = null;
    this.render();
  },

  openDocSheet(id) {
    this.state.modalDocId = id;
    this.state.activeModal = 'doc-sheet';
    this.render();
  },

  openModal(type) {
    this.state.activeModal = type;
    this.render();
  },

  closeModal() {
    this.state.activeModal = null;
    this.render();
  },

  setSearch(val) {
    this.state.liveSearch = val;
    this.render();
  },

  toggleCamAuto() {
    this.state.camAuto = !this.state.camAuto;
    this.render();
  },

  toggleCamFlash() {
    this.state.camFlash = !this.state.camFlash;
    this.render();
  },

  setCamMode(mode) {
    this.state.camMode = mode;
    this.render();
  },

  capturePage() {
    this.state.capturedPages += 1;
    this.toast('Captured Page 0' + this.state.capturedPages + ' · Perspective Quad Locked');
    this.render();
  },

  setEditorTab(tab) {
    this.state.editorTab = tab;
    this.render();
  },

  setFilter(name) {
    this.state.activeFilter = name;
    this.toast('Applied filter: ' + name);
    this.render();
  },

  saveDraftToPdf() {
    this.state.activeDocId = 'lease';
    this.state.screen = 'viewer';
    this.toast('Compiled ' + this.state.capturedPages + '-page Searchable PDF (%PDF-1.7)');
    this.render();
  },

  setFolder(name) {
    this.state.activeFolder = name;
    this.render();
  },

  setOcrTab(tab) {
    this.state.ocrTab = tab;
    this.render();
  },

  toggleBnDigits() {
    this.state.bnAsciiDigits = !this.state.bnAsciiDigits;
    this.render();
  },

  setSettingsSub(sub) {
    this.state.settingsSub = sub;
    this.render();
  },

  tapPin(key) {
    if (key === 'del') {
      this.state.pinInput = this.state.pinInput.slice(0, -1);
    } else if (this.state.pinInput.length < 4) {
      this.state.pinInput += key;
      if (this.state.pinInput.length === 4) {
        setTimeout(() => {
          this.state.pinInput = '12';
          this.state.settingsSub = null;
          this.toast('PBKDF2-HMAC-SHA256 Verified · Vault Unlocked');
          this.render();
        }, 280);
      }
    }
    this.render();
  },

  incCount() {
    this.state.pinCount = (this.state.pinCount || 8) + 1;
    this.render();
  },

  adjCount(delta) {
    this.state.pinCount = Math.max(1, (this.state.pinCount || 8) + delta);
    this.render();
  },

  applyRename(newName) {
    if (newName && newName.trim()) {
      this.state.draftTitle = newName.trim();
      this.toast('Renamed to: ' + this.state.draftTitle);
    }
    this.closeModal();
  },

  createFolder(folderName) {
    const clean = (folderName && folderName.trim()) ? folderName.trim() : 'Board Resolutions FY26';
    window.ScaneliqScreens.folderItems.unshift({
      id: 'custom_' + Date.now(),
      name: clean,
      count: '0 FILES',
      sub: 'Created Just Now · Local Vault'
    });
    this.state.activeModal = null;
    this.toast('Created folder: ' + clean);
    this.render();
  },

  toast(msg) {
    this.state.toastMsg = msg;
    this.render();
    clearTimeout(this._toastTimer);
    this._toastTimer = setTimeout(() => {
      this.state.toastMsg = null;
      this.render();
    }, 2400);
  },

  /* 7 Interactive User Journey Runners (Section 10) */
  runJourney(num) {
    switch (num) {
      case 1:
        this.state.screen = 'camera';
        this.state.camAuto = true;
        this.toast('Journey 1: Tap Shutter or Review (4) → Apply Filter → Save PDF');
        break;
      case 2:
        this.state.screen = 'home';
        this.state.activeModal = 'doc-sheet';
        this.state.modalDocId = 'lease';
        this.toast('Journey 2: Inspect Document Details, Tags, Rename & Share');
        break;
      case 3:
        this.state.screen = 'folders';
        this.state.activeFolder = 'Tax & Finance FY26';
        this.toast('Journey 3: Folder Vault Hierarchy & Multi-Select Batch Operations');
        break;
      case 4:
        this.state.screen = 'ocr-ai';
        this.state.ocrTab = 'bangla';
        this.toast('Journey 4: OCR & বাংলা Numeral Converter + Offline AI Brief');
        break;
      case 5:
        this.state.screen = 'pdf-suite';
        this.state.pdfSubTool = 'compress';
        this.toast('Journey 5: PDF Suite — Merge, Split, Compress (-59%), Sign & AES-256');
        break;
      case 6:
        this.state.screen = 'settings';
        this.state.settingsSub = 'lock';
        this.state.pinInput = '12';
        this.toast('Journey 6: App Lock PBKDF2 Keypad & Biometric Authentication');
        break;
      case 7:
        this.state.screen = 'settings';
        this.state.settingsSub = 'backup';
        this.toast('Journey 7: AES-256-CBC + HMAC-SHA256 (.scaneliq) Encrypted Backup');
        break;
    }
    this.render();
  },

  renderModalOverlay() {
    const m = this.state.activeModal;
    if (!m) return '';

    const doc = window.ScaneliqScreens.documents.find(d => d.id === this.state.modalDocId) || window.ScaneliqScreens.documents[0];

    let inner = '';
    if (m === 'import') {
      inner = `
        <div class="sub-title" style="margin-bottom:4px;">Import to Scaneliq (Screen 10)</div>
        <div style="font-size:12px;color:var(--text-2);margin-bottom:14px;">Select source for automatic edge detection or direct PDF indexing</div>
        <div class="doc-stream">
          <div class="hairline-row" onclick="App.closeModal(); App.go('editor'); App.toast('Imported 3 high-res photos from Gallery')">
            <div class="row-left"><div class="row-label-col"><div class="row-h">Photo Gallery (JPEG / PNG / HEIC)</div><div class="row-p">Auto-detect document boundaries & perspective warp</div></div></div>
            <span class="meta-tag accent">PHOTOS</span>
          </div>
          <div class="hairline-row" onclick="App.closeModal(); App.go('viewer'); App.toast('Imported PDF & queued background OCR index')">
            <div class="row-left"><div class="row-label-col"><div class="row-h">Local PDF Document (.pdf)</div><div class="row-p">Import directly into Vault with OCR indexing</div></div></div>
            <span class="meta-tag">PDF</span>
          </div>
          <div class="hairline-row" onclick="App.closeModal(); App.setSettingsSub('backup'); App.go('settings')">
            <div class="row-left"><div class="row-label-col"><div class="row-h">Encrypted Archive (.scaneliq)</div><div class="row-p">Restore AES-256-CBC + HMAC-SHA256 vault backup</div></div></div>
            <span class="meta-tag">VAULT</span>
          </div>
        </div>
      `;
    } else if (m === 'share') {
      inner = `
        <div class="sub-title" style="margin-bottom:4px;">Export & Share (Screen 20)</div>
        <div style="font-size:12px;color:var(--text-2);margin-bottom:12px;">Zero watermarks · 100% local generation</div>
        <div class="doc-stream">
          <div class="hairline-row" onclick="App.closeModal(); App.toast('Shared Searchable PDF (2.4 MB · UTF-8 Layer)')">
            <div class="row-left"><div class="row-label-col"><div class="row-h">Searchable PDF (%PDF-1.7)</div><div class="row-p">Includes invisible UTF-8 OCR text layer</div></div></div>
            <span class="meta-tag accent">RECOMMENDED</span>
          </div>
          <div class="hairline-row" onclick="App.closeModal(); App.toast('Exported Flattened Image PDF')">
            <div class="row-left"><div class="row-label-col"><div class="row-h">Flattened Image-Only PDF</div><div class="row-p">Rasterized pages for strict archival compliance</div></div></div>
            <span class="meta-tag">RASTER</span>
          </div>
          <div class="hairline-row" onclick="App.closeModal(); App.toast('Exported 300 DPI JPEG Gallery ZIP')">
            <div class="row-left"><div class="row-label-col"><div class="row-h">High-Resolution JPEG Images</div><div class="row-p">Individual page images (300 DPI)</div></div></div>
            <span class="meta-tag">JPG</span>
          </div>
          <div class="hairline-row" onclick="App.closeModal(); App.toast('Exported Recognized_OCR_Text.txt')">
            <div class="row-left"><div class="row-label-col"><div class="row-h">Plain Text (.txt) / CSV</div><div class="row-p">Extracted UTF-8 English & বাংলা text</div></div></div>
            <span class="meta-tag">TXT</span>
          </div>
        </div>
      `;
    } else if (m === 'rename') {
      inner = `
        <div class="sub-title" style="margin-bottom:6px;">Rename & Smart Tokens (Screens 32 & 59)</div>
        <div class="search-bar" style="margin-bottom:10px;">
          <input id="rename-input" type="text" value="${this.state.draftTitle}" />
        </div>
        <div style="display:flex;gap:6px;flex-wrap:wrap;margin-bottom:14px;">
          <span class="meta-tag" style="cursor:pointer" onclick="App.applyRename('2026-11-18_' + App.state.draftTitle)">+ [YYYY-MM-DD]</span>
          <span class="meta-tag" style="cursor:pointer" onclick="App.applyRename(App.state.draftTitle + ' [Legal]')">+ [Legal]</span>
          <span class="meta-tag" style="cursor:pointer" onclick="App.applyRename(App.state.draftTitle + ' [Tax FY26]')">+ [Tax FY26]</span>
          <span class="meta-tag" style="cursor:pointer" onclick="App.applyRename(App.state.draftTitle + ' [বাংলা]')">+ [বাংলা]</span>
        </div>
        <div style="display:flex;gap:10px;">
          <button class="btn-pill outline" style="flex:1" onclick="App.closeModal()">Cancel</button>
          <button class="btn-pill" style="flex:1" onclick="App.applyRename(this.closest('.bottom-sheet').querySelector('#rename-input').value)">Save Title</button>
        </div>
      `;
    } else if (m === 'new-folder') {
      inner = `
        <div class="sub-title" style="margin-bottom:6px;">New Vault Folder (Screen 30)</div>
        <div style="font-size:12px;color:var(--text-2);margin-bottom:10px;">Cycle-safe SQLite hierarchical folder</div>
        <div class="search-bar" style="margin-bottom:14px;">
          <input id="folder-input" type="text" value="Board Resolutions FY26" placeholder="Folder Name" />
        </div>
        <div style="display:flex;gap:10px;">
          <button class="btn-pill outline" style="flex:1" onclick="App.closeModal()">Cancel</button>
          <button class="btn-pill" style="flex:1" onclick="App.createFolder(this.closest('.bottom-sheet').querySelector('#folder-input').value)">Create Folder</button>
        </div>
      `;
    } else if (m === 'cam-settings') {
      inner = `
        <div class="sub-title" style="margin-bottom:6px;">Optical Camera Preferences (Screen 9)</div>
        <div class="doc-stream">
          <div class="hairline-row"><span class="row-h">Rule-of-Thirds Alignment Grid</span><div class="toggle on" onclick="this.classList.toggle('on')"></div></div>
          <div class="hairline-row"><span class="row-h">Auto Perspective Dewarp on Capture</span><div class="toggle on" onclick="this.classList.toggle('on')"></div></div>
          <div class="hairline-row"><span class="row-h">Default Capture Resolution</span><span class="meta-tag accent">300 DPI ARCHIVAL</span></div>
        </div>
        <button class="btn-pill" style="width:100%;margin-top:14px;" onclick="App.closeModal()">Done</button>
      `;
    } else if (m === 'pro') {
      inner = `
        <div class="folio-pill" style="display:inline-block;margin-bottom:6px;">TRANSPARENT EDITION DISCLOSURE · SCREEN 56</div>
        <div class="sub-title" style="margin-bottom:6px;">Scaneliq Local Vault vs. Proposed Pro</div>
        <p style="font-size:12px;color:var(--text-2);line-height:1.5;margin-bottom:12px;">
          Every local scanning, 7-filter enhancement, PDF Suite, OCR, offline AI summary, and AES-256 backup feature is <strong>100% unlocked locally with zero watermarks</strong>.
        </p>
        <div class="doc-stream">
          <div class="hairline-row"><span class="row-h">Local Scanning, PDF Suite & AES-256 Vault</span><span class="meta-tag success">INCLUDED FREE</span></div>
          <div class="hairline-row"><span class="row-h">Managed Cloud Sync & Cross-Device Relay</span><span class="meta-tag warning">PROPOSED PRO</span></div>
        </div>
        <button class="btn-pill" style="width:100%;margin-top:14px;" onclick="App.closeModal()">Close</button>
      `;
    } else if (m === 'doc-sheet') {
      inner = `
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;">
          <div>
            <div class="sub-title">${doc.title}</div>
            <div style="font-family:var(--font-mono);font-size:10px;color:var(--text-2);">${doc.tag} · ${doc.size} · ${doc.folder}</div>
          </div>
          <span class="meta-tag accent">SHA-256 OK</span>
        </div>
        <div style="padding:8px 10px;background:var(--surface-subtle);border-radius:8px;font-family:var(--font-mono);font-size:9.5px;color:var(--text-2);margin-bottom:10px;">
          SHA-256: 9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08
        </div>
        <div class="doc-stream">
          <div class="hairline-row" onclick="App.openModal('rename')"><span class="row-h">Rename Document (Screen 32)</span><span class="meta-tag">RENAME</span></div>
          <div class="hairline-row" onclick="App.closeModal(); App.go('folders')"><span class="row-h">Move or Duplicate to Folder (Screen 33)</span><span class="meta-tag">${doc.folder}</span></div>
          <div class="hairline-row" onclick="App.closeModal(); App.toast('Toggled Starred Favorite status')"><span class="row-h">Toggle Starred Priority (Screen 34)</span><span class="meta-tag">${doc.starred ? '★ STARRED' : '☆ STAR'}</span></div>
          <div class="hairline-row" onclick="App.openModal('share')"><span class="row-h">Export & Share Unwatermarked PDF (Screen 20)</span><span class="meta-tag accent">SHARE</span></div>
          <div class="hairline-row" onclick="App.closeModal(); App.toast('Moved to 30-Day Trash Recovery (Screen 37)')"><span class="row-h" style="color:var(--danger)">Move to 30-Day Trash (Screen 37)</span><span class="meta-tag" style="color:var(--danger)">TRASH</span></div>
        </div>
      `;
    }

    return `<div class="sheet-backdrop" onclick="App.closeModal()">
      <div class="bottom-sheet" onclick="event.stopPropagation()">
        <div class="sheet-handle"></div>
        ${inner}
      </div>
    </div>`;
  },

  renderViewportContent() {
    const S = window.ScaneliqScreens;
    let screenHtml = '';
    switch (this.state.screen) {
      case 'home':       screenHtml = S.home(this.state); break;
      case 'search':     screenHtml = S.search(this.state); break;
      case 'camera':     screenHtml = S.camera(this.state); break;
      case 'editor':     screenHtml = S.editor(this.state); break;
      case 'viewer':     screenHtml = S.viewer(this.state); break;
      case 'folders':    screenHtml = S.folders(this.state); break;
      case 'pdf-suite':  screenHtml = S.pdfSuite(this.state); break;
      case 'ocr-ai':     screenHtml = S.ocrAi(this.state); break;
      case 'settings':   screenHtml = S.settings(this.state); break;
      case 'onboarding': screenHtml = S.onboarding(this.state); break;
      default:           screenHtml = S.home(this.state);
    }

    const modalHtml = this.renderModalOverlay();
    const toastHtml = this.state.toastMsg ? `<div class="toast-pill">${this.state.toastMsg}</div>` : '';

    const isCam = this.state.screen === 'camera';

    return `
      <div class="status-bar" style="${isCam ? 'background:#090A0D;color:#F4F4F6;' : ''}">
        <span>9:41</span>
        <div class="status-icons">
          <svg width="14" height="11"><use href="#ic-signal"/></svg>
          <svg width="14" height="11"><use href="#ic-wifi"/></svg>
          <svg width="20" height="11"><use href="#ic-battery"/></svg>
        </div>
      </div>
      ${screenHtml}
      ${modalHtml}
      ${toastHtml}
    `;
  },

  render() {
    const html = this.renderViewportContent();
    const vpLight = document.getElementById('viewport-light');
    const vpDark = document.getElementById('viewport-dark');
    if (vpLight) vpLight.innerHTML = html;
    if (vpDark) vpDark.innerHTML = html;

    // Highlight active screen button in studio shell
    const currentKey = this.state.screen === 'pdf-suite' && this.state.pdfSubTool === 'receipt'
      ? 'receipt'
      : (this.state.screen === 'settings' && this.state.settingsSub === 'lock')
        ? 'lock'
        : (this.state.screen === 'settings' && this.state.settingsSub === 'backup')
          ? 'backup'
          : this.state.screen;

    document.querySelectorAll('[data-screen-btn]').forEach(btn => {
      btn.classList.toggle('active', btn.getAttribute('data-screen-btn') === currentKey);
    });
  }
};

document.addEventListener('DOMContentLoaded', () => {
  window.App.init();
});
