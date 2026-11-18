/* ==========================================================================
   SCANELIQ — MODULAR SCREEN RENDERERS (CONCEPT A: EDITORIAL GALLERY MINIMAL)
   Covers all 8 Screen Groups & 7 User Journeys at 393 × 852 Logical Pixels
   ========================================================================== */

window.ScaneliqScreens = {
  documents: [
    {
      id: 'lease',
      title: 'Commercial Lease Agreement',
      tag: 'PDF · 12P',
      size: '2.4 MB',
      date: 'Today, 14:20',
      folder: 'Legal & Property',
      starred: true,
      type: 'seal',
      ocrExcerpt: 'Clause 8.2: Lessee agrees to an annual rent of $84,200 payable in quarterly installments…'
    },
    {
      id: 'bangla',
      title: 'বাংলা জমির দলিল — খতিয়ান ৪১২',
      tag: 'OCR · BN',
      size: '6 Pages',
      date: 'Yesterday',
      folder: 'Legal & Property',
      starred: true,
      type: 'bangla',
      ocrExcerpt: 'তফসিল পরিচয়: মৌজা ধানমন্ডি, খতিয়ান নং ৪১২, দাগ নং ১৮৯০, মোট জমির পরিমাণ ০.১৫৫০ একর…'
    },
    {
      id: 'nid',
      title: 'National ID & Passport Dual Sheet',
      tag: '2-IN-1',
      size: 'Locked',
      date: 'Nov 15',
      folder: 'Identity & KYC',
      starred: false,
      type: 'id',
      ocrExcerpt: 'REPUBLIC OF BANGLADESH · NATIONAL ID CARD · ID NO: 849 201 9482'
    },
    {
      id: 'invoice',
      title: 'Square Pharmaceuticals Invoice #884',
      tag: 'RECEIPT',
      size: '৳ 4,830',
      date: 'Nov 12',
      folder: 'Tax & Finance',
      starred: true,
      type: 'invoice',
      ocrExcerpt: 'INV-2026-884 · Subtotal: ৳ 4,200.00 · VAT (15%): ৳ 630.00 · Grand Total: ৳ 4,830.00'
    }
  ],

  folderItems: [
    { id: 'tax', name: 'Tax & Finance FY26', count: '14 FILES', sub: '2 Subfolders · Updated Today' },
    { id: 'legal', name: 'Legal & Property Deeds', count: '8 FILES', sub: 'বাংলা & English Contracts' },
    { id: 'id', name: 'Identity & KYC Vault', count: '6 FILES', sub: 'AES-256 Protected' },
    { id: 'receipts', name: 'Receipts & Invoices', count: '11 FILES', sub: 'CSV Ledger Ready' },
    { id: 'medical', name: 'Medical Records', count: '3 FILES', sub: 'Searchable PDFs' }
  ],

  renderThumb(doc) {
    if (doc.type === 'bangla') {
      return `<div class="doc-sheet">
        <div>
          <div style="font-size:4.5px;font-weight:700;color:#0052FF;">খতিয়ান নং ৪১২</div>
          <div class="mini-text-line" style="margin-top:3px;width:92%"></div>
          <div class="mini-text-line" style="margin-top:2px;width:80%"></div>
          <div class="mini-text-line" style="margin-top:2px;width:88%"></div>
        </div>
        <div class="mini-sig"></div>
      </div>`;
    }
    if (doc.type === 'id') {
      return `<div class="doc-sheet" style="justify-content:space-around;">
        <div class="sheet-id-box"><div class="sheet-avatar"></div><div style="flex:1"><div class="mini-text-line"></div><div class="mini-text-line" style="margin-top:2px;width:70%"></div></div></div>
        <div class="sheet-id-box"><div style="flex:1"><div class="mini-text-line"></div><div class="mini-text-line" style="margin-top:2px;width:80%"></div></div></div>
      </div>`;
    }
    if (doc.type === 'invoice') {
      return `<div class="doc-sheet">
        <div>
          <div style="font-size:4.5px;font-weight:700;">INVOICE #884</div>
          <div class="mini-table" style="margin-top:4px;">
            <div class="mini-table-row"><span>Qty 12</span><span>৳4,200</span></div>
            <div class="mini-table-row"><span>VAT</span><span>৳630</span></div>
          </div>
        </div>
        <div style="font-size:4.5px;font-weight:700;text-align:right;color:#059669;">PAID</div>
      </div>`;
    }
    return `<div class="doc-sheet">
      <div>
        <div style="font-size:4.5px;font-weight:700;color:#111;">LEASE CONTRACT</div>
        <div class="mini-text-line" style="margin-top:3px;width:95%"></div>
        <div class="mini-text-line" style="margin-top:2px;width:85%"></div>
        <div class="mini-text-line" style="margin-top:2px;width:90%"></div>
        <div class="mini-text-line" style="margin-top:2px;width:60%"></div>
      </div>
      <div class="sheet-seal"></div>
    </div>`;
  },

  renderBottomNav(activeTab) {
    return `<nav class="bottom-nav">
      <button class="nav-tab ${activeTab === 'home' ? 'active' : ''}" onclick="App.go('home')">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="${activeTab === 'home' ? '2.2' : '1.8'}"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
        <span>Scans</span>
      </button>
      <button class="nav-tab ${activeTab === 'folders' ? 'active' : ''}" onclick="App.go('folders')">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="${activeTab === 'folders' ? '2.2' : '1.8'}"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/></svg>
        <span>Folders</span>
      </button>
      <button class="nav-tab ${activeTab === 'pdf-suite' ? 'active' : ''}" onclick="App.go('pdf-suite')">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="${activeTab === 'pdf-suite' ? '2.2' : '1.8'}"><rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/></svg>
        <span>PDF Suite</span>
      </button>
      <div class="home-indicator"></div>
    </nav>`;
  },

  /* 1. APPROVED CONCEPT A HOME DASHBOARD (+ Scopes & Multi-Select) */
  home(state) {
    const docs = this.documents.filter(d => {
      if (state.homeScope === 'starred' && !d.starred) return false;
      if (state.searchQuery && !d.title.toLowerCase().includes(state.searchQuery.toLowerCase())) return false;
      return true;
    });

    return `<div class="screen-root">
      <header class="header">
        ${state.selectMode ? `
          <div class="brand-lockup">
            <button class="icon-hit" onclick="App.toggleSelectMode()"><svg width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg></button>
            <span class="sub-title">${state.selectedIds.length} Selected</span>
          </div>
          <button class="section-action" onclick="App.selectAllDocs()">Select all</button>
        ` : `
          <div class="brand-lockup">
            <div class="brand-glyph"><svg width="15" height="15"><use href="#ic-glyph"/></svg></div>
            <span class="brand-word">Scaneliq</span>
          </div>
          <div class="header-actions">
            <button class="icon-hit" title="Select Multiple" onclick="App.toggleSelectMode()">
              <svg width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M9 11l3 3L22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/></svg>
            </button>
            <button class="icon-hit" title="Settings" onclick="App.go('settings')">
              <svg width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9c.26.6.85 1 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>
            </button>
          </div>
        `}
      </header>

      <div class="search-zone">
        <div class="search-bar" onclick="App.go('search')">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
          <span>Search titles or recognized text…</span>
          <span class="search-kbd" style="margin-left:auto">OCR</span>
        </div>

        <div class="scope-tabs">
          <div class="scope-list">
            <button class="scope-tab ${state.homeScope === 'recent' ? 'active' : ''}" onclick="App.setHomeScope('recent')">Recent<span class="scope-count">42</span></button>
            <button class="scope-tab ${state.homeScope === 'starred' ? 'active' : ''}" onclick="App.setHomeScope('starred')">Starred<span class="scope-count">7</span></button>
            <button class="scope-tab ${state.homeScope === 'folders' ? 'active' : ''}" onclick="App.go('folders')">Folders<span class="scope-count">5</span></button>
          </div>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--text-2)" stroke-width="1.8"><line x1="4" y1="6" x2="20" y2="6"/><line x1="4" y1="12" x2="14" y2="12"/><line x1="4" y1="18" x2="9" y2="18"/></svg>
        </div>
      </div>

      <div class="content">
        <div class="folio-section">
          <div class="section-head">
            <span class="section-title">Continue working</span>
            <button class="section-action" onclick="App.go('editor')">Resume draft</button>
          </div>
          <div class="folio-card" onclick="App.go('editor')">
            <div class="folio-paper-stack">
              <div class="paper-back"></div>
              <div class="paper-front">
                <div>
                  <div class="mini-doc-header"><span class="mini-doc-title">TAX RETURN 2026</span><span class="mini-doc-date">FORM-1040</span></div>
                  <div class="mini-doc-body">
                    <div class="mini-text-line" style="width:90%"></div>
                    <div class="mini-text-line" style="width:72%"></div>
                    <div class="mini-table">
                      <div class="mini-table-row"><span>Gross</span><span>$84,200</span></div>
                      <div class="mini-table-row"><span>Tax</span><span>$12,450</span></div>
                    </div>
                    <div class="mini-text-line" style="width:85%"></div>
                  </div>
                </div>
                <div class="mini-sig"></div>
              </div>
            </div>
            <div class="folio-info">
              <div class="folio-pill">UNFINISHED · ${state.capturedPages} PAGES</div>
              <div class="folio-name">${state.draftTitle}</div>
              <div class="folio-sub">Edited 14 mins ago · ${state.activeFilter}</div>
              <div class="folio-actions">
                <span onclick="event.stopPropagation(); App.go('camera')">Add pages</span>
                <span style="color:var(--accent)" onclick="event.stopPropagation(); App.saveDraftToPdf()">Save PDF</span>
              </div>
            </div>
          </div>
        </div>

        <div class="section-head" style="margin-top: 16px; margin-bottom: 4px;">
          <span class="section-title">November 2026</span>
          <button class="section-action" onclick="App.go('folders')">All files</button>
        </div>

        <div class="doc-stream">
          ${docs.map(doc => {
            const isSel = state.selectedIds.includes(doc.id);
            return `<div class="stream-row" onclick="${state.selectMode ? `App.toggleSelectDoc('${doc.id}')` : `App.openDoc('${doc.id}')`}">
              ${state.selectMode ? `<div class="select-circle ${isSel ? 'checked' : ''}">${isSel ? '✓' : ''}</div>` : ''}
              ${this.renderThumb(doc)}
              <div class="row-main">
                <div class="row-title">${doc.title}</div>
                <div class="row-meta">
                  <span class="meta-tag">${doc.tag}</span>
                  <span>${doc.size}</span>
                  <span>${doc.date}</span>
                </div>
              </div>
              <div class="row-more" onclick="event.stopPropagation(); App.openDocSheet('${doc.id}')">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/></svg>
              </div>
            </div>`;
          }).join('')}
        </div>
      </div>

      ${state.selectMode ? `
        <nav class="bottom-nav" style="padding: 8px 16px 26px;">
          <button class="nav-tab active" onclick="App.toast('Moved ${state.selectedIds.length} documents to Tax & Finance')"><svg width="18" height="18"><use href="#ic-folder"/></svg><span>Move</span></button>
          <button class="nav-tab active" onclick="App.toast('Applied tag: VERIFIED')"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z"/></svg><span>Tag</span></button>
          <button class="nav-tab active" style="color:var(--accent)" onclick="App.go('pdf-suite', 'merge')"><svg width="18" height="18"><use href="#ic-doc"/></svg><span>Merge PDF</span></button>
          <button class="nav-tab active" onclick="App.openModal('share')"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8"/><polyline points="16 6 12 2 8 6"/><line x1="12" y1="2" x2="12" y2="15"/></svg><span>Share</span></button>
          <button class="nav-tab active" style="color:var(--danger)" onclick="App.toast('Moved to 30-day Trash')"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/></svg><span>Trash</span></button>
          <div class="home-indicator"></div>
        </nav>
      ` : `
        <div class="fab-cluster">
          <div class="fab-secondary" title="Import from Gallery" onclick="App.openModal('import')">
            <svg width="19" height="19"><use href="#ic-gallery"/></svg>
          </div>
          <button class="fab-primary" onclick="App.go('camera')">
            <svg width="18" height="18"><use href="#ic-camera"/></svg>
            Scan
          </button>
        </div>
        ${this.renderBottomNav('home')}
      `}
    </div>`;
  },

  /* 2. GLOBAL SEARCH & FTS5 OCR SNIPPETS (Screens 5 & 35) */
  search(state) {
    const q = (state.liveSearch || 'Lease').toLowerCase();
    return `<div class="screen-root">
      <header class="header" style="gap:10px;">
        <div class="search-bar" style="flex:1; cursor:text;">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
          <input type="text" value="${state.liveSearch || ''}" placeholder="Search titles, বাংলা or English OCR…" oninput="App.setSearch(this.value)" autofocus />
        </div>
        <button class="section-action" onclick="App.go('home')">Cancel</button>
      </header>

      <div class="search-zone" style="padding-bottom:8px;">
        <div class="scope-tabs">
          <div class="scope-list">
            <button class="scope-tab active">All Matches<span class="scope-count">4</span></button>
            <button class="scope-tab">OCR Text<span class="scope-count">3</span></button>
            <button class="scope-tab">Titles<span class="scope-count">2</span></button>
          </div>
        </div>
      </div>

      <div class="content">
        <div class="section-head" style="margin-top:8px;">
          <span class="section-title">Matches Inside Recognized OCR Text</span>
          <span class="meta-tag accent">SQLITE INDEX</span>
        </div>

        <div class="doc-stream">
          ${this.documents.filter(d => !state.liveSearch || d.title.toLowerCase().includes(q) || d.ocrExcerpt.toLowerCase().includes(q)).map(doc => `
            <div class="stream-row" style="align-items:flex-start;" onclick="App.openDoc('${doc.id}')">
              ${this.renderThumb(doc)}
              <div class="row-main">
                <div class="row-title">${doc.title}</div>
                <div class="row-meta" style="margin-bottom:6px;">
                  <span class="meta-tag">${doc.tag}</span>
                  <span>${doc.folder}</span>
                  <span>${doc.date}</span>
                </div>
                <div style="padding:7px 9px; border-left:2px solid var(--accent); background:var(--surface-subtle); border-radius:0 6px 6px 0; font-size:11.5px; color:var(--text-2); line-height:1.45;">
                  ${doc.ocrExcerpt}
                </div>
              </div>
            </div>
          `).join('')}
        </div>
      </div>
    </div>`;
  },

  /* 3. OPTICAL CAMERA STUDIO (Screens 7, 8, 9) */
  camera(state) {
    return `<div class="screen-root camera-studio">
      <div class="cam-top-bar">
        <button class="icon-hit" style="color:#FFF" onclick="App.go('home')">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
        </button>
        <div class="cam-pill" onclick="App.toggleCamAuto()">
          <span style="width:7px;height:7px;border-radius:50%;background:${state.camAuto ? '#3B82F6' : '#8E929F'}"></span>
          ${state.camAuto ? 'AUTO DETECTION' : 'MANUAL SHUTTER'}
        </div>
        <div style="display:flex;gap:4px;">
          <button class="icon-hit" style="color:${state.camFlash ? '#FBBF24' : '#FFF'}" onclick="App.toggleCamFlash()" title="Flash">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>
          </button>
          <button class="icon-hit" style="color:#FFF" onclick="App.openModal('cam-settings')" title="Camera Settings">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4"/></svg>
          </button>
        </div>
      </div>

      <div class="cam-stage">
        <div class="detected-sheet">
          ${state.camAuto ? `
            <div class="quad-border">
              <span class="quad-node" style="top:-6px;left:-6px;"></span>
              <span class="quad-node" style="top:-6px;right:-6px;"></span>
              <span class="quad-node" style="bottom:-6px;left:-6px;"></span>
              <span class="quad-node" style="bottom:-6px;right:-6px;"></span>
            </div>
          ` : ''}
          <div>
            <div style="display:flex;justify-content:space-between;border-bottom:1px solid #E2E8F0;padding-bottom:4px;">
              <span style="font-size:8px;font-weight:700;color:#0052FF;">${state.camMode === 'id' ? 'NATIONAL ID · FRONT' : 'TAX RETURN FY2026'}</span>
              <span style="font-size:7px;color:#64748B;">PAGE 0${state.capturedPages + 1}</span>
            </div>
            <div class="mini-text-line" style="margin-top:8px;width:92%;height:3px;"></div>
            <div class="mini-text-line" style="margin-top:5px;width:80%;height:3px;"></div>
            <div class="mini-text-line" style="margin-top:5px;width:86%;height:3px;"></div>
            <div class="mini-table" style="margin-top:10px;padding:5px;">
              <div class="mini-table-row" style="font-size:7px;"><span>Assessable Income</span><span>$84,200.00</span></div>
              <div class="mini-table-row" style="font-size:7px;"><span>Withholding Tax</span><span>$12,450.00</span></div>
            </div>
          </div>
          <div style="display:flex;justify-content:space-between;align-items:flex-end;">
            <span style="font-size:6.5px;color:#64748B;">ISO A4 · 300 DPI</span>
            <div class="mini-sig" style="width:36px;"></div>
          </div>
        </div>

        <div class="cam-pill" style="position:absolute;bottom:14px;background:rgba(13,14,17,0.85);border-color:#3B82F6;">
          ${state.camAuto ? 'Boundary locked · Tap shutter or hold steady' : 'Manual alignment ready · Tap shutter'}
        </div>
      </div>

      <div class="cam-modes">
        ${[
          ['doc', 'Document'],
          ['batch', 'Batch'],
          ['id', 'ID 2-in-1'],
          ['book', 'Book'],
          ['receipt', 'Receipt'],
          ['qr', 'QR']
        ].map(([k, lbl]) => `<span class="${state.camMode === k ? 'active' : ''}" onclick="App.setCamMode('${k}')">${lbl}</span>`).join('')}
      </div>

      <div class="cam-shutter-bar">
        <div style="position:relative;cursor:pointer;" onclick="App.go('editor')" title="Captured Page Stack">
          <div class="doc-sheet" style="width:44px;height:56px;">
            <div class="mini-text-line" style="width:85%"></div>
            <div class="mini-text-line" style="width:70%"></div>
            <div class="mini-sig"></div>
          </div>
          <span style="position:absolute;top:-6px;right:-6px;background:#0052FF;color:#FFF;font-family:var(--font-mono);font-size:10px;font-weight:700;padding:1px 6px;border-radius:999px;">${state.capturedPages}</span>
        </div>

        <div class="shutter-ring" onclick="App.capturePage()" title="Capture Page">
          <div class="shutter-disc"></div>
        </div>

        <button class="btn-pill sm" onclick="App.go('editor')">Review (${state.capturedPages}) →</button>
      </div>
    </div>`;
  },

  /* 4. SCAN PREVIEW & EDITOR STUDIO (Screens 11–18) */
  editor(state) {
    const tab = state.editorTab || 'filters';
    const filters = ['Original', 'Magic Color', 'Crisp B&W', 'Adaptive', 'Grayscale', 'Whiteboard', 'Ink Boost'];

    return `<div class="screen-root">
      <header class="header" style="border-bottom:1px solid var(--hairline);">
        <div class="brand-lockup">
          <button class="icon-hit" onclick="App.go('home')"><svg width="20" height="20"><use href="#ic-back"/></svg></button>
          <div onclick="App.openModal('rename')" style="cursor:pointer;">
            <div class="sub-title" style="font-size:15.5px;">${state.draftTitle} ✎</div>
            <div style="font-family:var(--font-mono);font-size:10px;color:var(--text-2);">PAGE 01 OF 0${state.capturedPages} · ${state.activeFilter.toUpperCase()}</div>
          </div>
        </div>
        <button class="btn-pill sm" onclick="App.saveDraftToPdf()">Save PDF</button>
      </header>

      <div class="content" style="padding-bottom:16px;display:flex;flex-direction:column;justify-content:space-between;">
        ${tab === 'organize' ? `
          <!-- Multi-Page Organizer Grid (Screens 15 & 16) -->
          <div>
            <div class="section-head" style="margin-top:8px;">
              <span class="section-title">Drag to reorder · Tap page to edit</span>
              <button class="section-action" onclick="App.capturePage()">+ Add page</button>
            </div>
            <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-top:8px;">
              ${Array.from({ length: state.capturedPages }).map((_, idx) => `
                <div style="background:var(--surface);border:1px solid ${idx === 0 ? 'var(--accent)' : 'var(--hairline)'};border-radius:10px;padding:10px;display:flex;flex-direction:column;gap:8px;">
                  <div style="display:flex;justify-content:space-between;align-items:center;">
                    <span class="meta-tag accent">PAGE 0${idx + 1}</span>
                    <span style="font-size:11px;color:var(--text-3);cursor:pointer;" onclick="App.toast('Rotated Page 0${idx + 1} by 90°')">↻ 90°</span>
                  </div>
                  <div class="doc-sheet" style="width:100%;height:142px;padding:10px;">
                    <div>
                      <div class="mini-doc-title">TAX RETURN FY2026</div>
                      <div class="mini-text-line" style="margin-top:6px;width:90%"></div>
                      <div class="mini-text-line" style="margin-top:4px;width:78%"></div>
                      <div class="mini-table" style="margin-top:8px;"><div class="mini-table-row"><span>Net</span><span>$71,750</span></div></div>
                    </div>
                    <div class="mini-sig"></div>
                  </div>
                </div>
              `).join('')}
            </div>
          </div>
        ` : `
          <!-- Primary Paper Preview Stage (Screens 11, 12, 13, 14) -->
          <div style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;position:relative;margin:8px 0;background:var(--surface-subtle);border-radius:12px;padding:16px;">
            ${tab === 'crop' ? `
              <div class="cam-Loupe">
                <div style="text-align:center;">1.8× LOUPE<br><span style="color:#0052FF;">┼</span></div>
              </div>
            ` : ''}
            <div class="detected-sheet" style="width:205px;height:272px;box-shadow:var(--paper-shadow);border:1px solid #D8D6CE;filter:${state.activeFilter === 'Crisp B&W' ? 'contrast(1.45) grayscale(1)' : state.activeFilter === 'Grayscale' ? 'grayscale(1)' : 'none'}">
              ${tab === 'crop' ? `
                <div class="quad-border">
                  <span class="quad-node" style="top:-6px;left:-6px;"></span>
                  <span class="quad-node" style="top:-6px;right:-6px;"></span>
                  <span class="quad-node" style="bottom:-6px;left:-6px;"></span>
                  <span class="quad-node" style="bottom:-6px;right:-6px;"></span>
                </div>
              ` : ''}
              <div>
                <div class="mini-doc-header"><span class="mini-doc-title">ANNUAL TAX RETURN 2026</span><span class="mini-doc-date">FORM 1040</span></div>
                <div class="mini-text-line" style="margin-top:7px;width:94%;height:2.5px;"></div>
                <div class="mini-text-line" style="margin-top:4px;width:82%;height:2.5px;"></div>
                <div class="mini-table" style="margin-top:8px;padding:4px;">
                  <div class="mini-table-row" style="font-size:6.5px;"><span>Gross Assessable</span><span>$84,200</span></div>
                  <div class="mini-table-row" style="font-size:6.5px;"><span>Verified Deductions</span><span>$12,450</span></div>
                  <div class="mini-table-row" style="font-size:6.5px;color:#0052FF;"><span>Net Taxable</span><span>$71,750</span></div>
                </div>
                <div class="mini-text-line" style="margin-top:8px;width:90%;height:2.5px;"></div>
                <div class="mini-text-line" style="margin-top:4px;width:65%;height:2.5px;"></div>
              </div>
              <div style="display:flex;justify-content:space-between;align-items:center;">
                <span style="font-size:6px;color:#64748B;">FILTER: ${state.activeFilter.toUpperCase()}</span>
                <div class="mini-sig" style="width:32px;"></div>
              </div>
            </div>
            <button class="meta-tag" style="position:absolute;bottom:10px;right:12px;cursor:pointer;border:1px solid var(--hairline);" onclick="App.toast('Showing original raw photo comparison')">Hold to Compare</button>
          </div>

          <!-- Contextual Sub-Panel -->
          <div>
            ${tab === 'filters' ? `
              <div class="filter-ribbon">
                ${filters.map(f => `
                  <div class="filter-item ${state.activeFilter === f ? 'active' : ''}" onclick="App.setFilter('${f}')">
                    <div class="filter-sheet">
                      <div class="mini-text-line" style="width:85%"></div>
                      <div class="mini-text-line" style="width:70%"></div>
                      <div class="mini-sig" style="width:16px;"></div>
                    </div>
                    <span class="filter-name">${f}</span>
                  </div>
                `).join('')}
              </div>
            ` : tab === 'crop' ? `
              <div style="display:flex;justify-content:space-between;padding:12px 0;border-top:1px solid var(--hairline);">
                <button class="btn-pill outline sm" onclick="App.toast('Auto-detected 4 document corners')">Auto Fit Quad</button>
                <button class="btn-pill outline sm" onclick="App.toast('Rotated 90° clockwise')">Rotate 90°</button>
                <button class="btn-pill sm" onclick="App.setEditorTab('filters')">Apply Crop</button>
              </div>
            ` : `
              <div style="padding:6px 0;">
                <div class="hairline-row" style="padding:8px 0;">
                  <span style="font-size:12px;font-weight:600;">Flatten Paper Shadows</span>
                  <div class="toggle on" onclick="this.classList.toggle('on')"></div>
                </div>
                <div class="hairline-row" style="padding:8px 0;">
                  <span style="font-size:12px;font-weight:600;">Spot Eraser & Privacy Redact</span>
                  <button class="btn-pill outline sm" onclick="App.toast('Eraser / Mosaic brush active on canvas')">Brush Tool</button>
                </div>
              </div>
            `}
          </div>
        `}

        <!-- Editorial 4-Mode Editor Switcher -->
        <div class="scope-tabs" style="padding-top:8px;border-top:1px solid var(--hairline);border-bottom:none;">
          <button class="scope-tab ${tab === 'crop' ? 'active' : ''}" onclick="App.setEditorTab('crop')">Crop & Perspective</button>
          <button class="scope-tab ${tab === 'filters' ? 'active' : ''}" onclick="App.setEditorTab('filters')">Filters (7)</button>
          <button class="scope-tab ${tab === 'enhance' ? 'active' : ''}" onclick="App.setEditorTab('enhance')">Enhance</button>
          <button class="scope-tab ${tab === 'organize' ? 'active' : ''}" onclick="App.setEditorTab('organize')">Pages (${state.capturedPages})</button>
        </div>
      </div>
    </div>`;
  },

  /* 5. PDF VIEWER & 5-ACTION BOTTOM DOCK (Screens 19, 20, 31, 36) */
  viewer(state) {
    const doc = this.documents.find(d => d.id === state.activeDocId) || this.documents[0];
    return `<div class="screen-root">
      <header class="header" style="border-bottom:1px solid var(--hairline);">
        <div class="brand-lockup" style="min-width:0;flex:1;">
          <button class="icon-hit" onclick="App.go('home')"><svg width="20" height="20"><use href="#ic-back"/></svg></button>
          <div style="min-width:0;">
            <div class="sub-title" style="font-size:15.5px;">${doc.title}</div>
            <div style="font-family:var(--font-mono);font-size:10px;color:var(--text-2);">${doc.tag} · ${doc.size} · SEARCHABLE LAYER</div>
          </div>
        </div>
        <div class="header-actions">
          <button class="icon-hit" title="Search in PDF" onclick="App.go('search')"><svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg></button>
          <button class="icon-hit" title="Share PDF" onclick="App.openModal('share')"><svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8"/><polyline points="16 6 12 2 8 6"/><line x1="12" y1="2" x2="12" y2="15"/></svg></button>
        </div>
      </header>

      <div class="content" style="background:var(--surface-subtle);padding:16px 24px 96px;display:flex;flex-direction:column;gap:14px;">
        <div style="background:#FFFFFF;color:#141413;border:1px solid #D8D6CE;border-radius:4px;box-shadow:var(--paper-shadow);padding:20px 18px;display:flex;flex-direction:column;gap:10px;">
          <div style="display:flex;justify-content:space-between;align-items:center;border-bottom:1px solid #E2E8F0;padding-bottom:8px;">
            <span style="font-family:var(--font-head);font-size:13px;font-weight:700;color:#0052FF;">${doc.title.toUpperCase()}</span>
            <span style="font-family:var(--font-mono);font-size:9.5px;color:#64748B;">PAGE 01</span>
          </div>
          <p style="font-size:11.5px;line-height:1.55;color:#334155;">${doc.ocrExcerpt}</p>
          <div style="border:1px solid #E2E8F0;background:#F8FAFC;padding:10px;border-radius:4px;display:flex;flex-direction:column;gap:5px;font-size:11px;">
            <div style="display:flex;justify-content:space-between;"><span>Document Classification</span><strong>${doc.folder}</strong></div>
            <div style="display:flex;justify-content:space-between;"><span>OCR Text Layer</span><strong>Embedded (UTF-8)</strong></div>
            <div style="display:flex;justify-content:space-between;color:#0052FF;"><span>Integrity Verification</span><strong>%PDF-1.7 Validated</strong></div>
          </div>
          <div class="mini-text-line" style="width:94%;height:3px;margin-top:4px;"></div>
          <div class="mini-text-line" style="width:88%;height:3px;"></div>
          <div class="mini-text-line" style="width:70%;height:3px;"></div>
          <div style="display:flex;justify-content:space-between;align-items:center;margin-top:10px;padding-top:8px;border-top:1px solid #F1F5F9;">
            <span style="font-family:var(--font-mono);font-size:9px;color:#64748B;">SHA-256 VERIFIED</span>
            <div style="font-family:cursive;font-size:12px;color:#0052FF;border-bottom:1px solid #0052FF;">A. Emon · Signed</div>
          </div>
        </div>

        <div style="display:flex;justify-content:space-between;align-items:center;background:var(--surface);border:1px solid var(--hairline);border-radius:999px;padding:6px 14px;">
          <button class="section-action" onclick="App.toast('Zoomed 90%')">－ Zoom</button>
          <span style="font-family:var(--font-mono);font-size:11px;">PAGE 01 OF 12 · 100%</span>
          <button class="section-action" onclick="App.toast('Zoomed 125%')">＋ Zoom</button>
        </div>
      </div>

      <nav class="bottom-nav" style="padding:8px 14px 26px;">
        <button class="nav-tab active" onclick="App.go('editor')"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 20h9"/><path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"/></svg><span>Edit</span></button>
        <button class="nav-tab active" onclick="App.setEditorTab('organize'); App.go('editor')"><svg width="18" height="18"><use href="#ic-grid"/></svg><span>Pages</span></button>
        <button class="nav-tab active" style="color:var(--accent)" onclick="App.go('ocr-ai')"><svg width="18" height="18"><use href="#ic-doc"/></svg><span>OCR & AI</span></button>
        <button class="nav-tab active" onclick="App.go('pdf-suite', 'sign')"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M2 22h20"/><path d="M6.36 17.4 4 20l2.6-2.36 9.9-9.9a2.1 2.1 0 0 0-3-3l-9.9 9.9z"/></svg><span>Sign</span></button>
        <button class="nav-tab active" onclick="App.openDocSheet('${doc.id}')"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/></svg><span>Details</span></button>
        <div class="home-indicator"></div>
      </nav>
    </div>`;
  },

  /* 6. FOLDERS & VAULT HIERARCHY (Tab 2 — Screen 30) */
  folders(state) {
    return `<div class="screen-root">
      <header class="header">
        <div class="brand-lockup">
          <span class="brand-word">Folders</span>
          <span class="meta-tag">5 VAULTS</span>
        </div>
        <div class="header-actions">
          <button class="btn-pill outline sm" onclick="App.openModal('new-folder')">+ New Folder</button>
        </div>
      </header>

      <div class="search-zone">
        <div style="font-family:var(--font-mono);font-size:10.5px;color:var(--text-2);padding-bottom:10px;border-bottom:1px solid var(--hairline);">
          VAULT ROOT / ${state.activeFolder ? state.activeFolder.toUpperCase() : 'ALL FOLDERS'}
          ${state.activeFolder ? `<button class="section-action" style="float:right" onclick="App.setFolder(null)">← Up to Root</button>` : ''}
        </div>
      </div>

      <div class="content">
        ${!state.activeFolder ? `
          <div class="section-head"><span class="section-title">Hierarchical Folders</span><span class="meta-tag">CYCLE-SAFE</span></div>
          <div class="doc-stream">
            ${this.folderItems.map(f => `
              <div class="hairline-row" onclick="App.setFolder('${f.name}')">
                <div class="row-left">
                  <div class="row-icon"><svg width="22" height="22"><use href="#ic-folder"/></svg></div>
                  <div class="row-label-col">
                    <div class="row-h">${f.name}</div>
                    <div class="row-p">${f.sub}</div>
                  </div>
                </div>
                <span class="meta-tag">${f.count}</span>
              </div>
            `).join('')}
          </div>
        ` : ''}

        <div class="section-head" style="margin-top:18px;">
          <span class="section-title">${state.activeFolder || 'Unfiled Root Documents'}</span>
          <button class="section-action" onclick="App.toggleSelectMode(); App.go('home')">Batch Select</button>
        </div>
        <div class="doc-stream">
          ${this.documents.map(doc => `
            <div class="stream-row" onclick="App.openDoc('${doc.id}')">
              ${this.renderThumb(doc)}
              <div class="row-main">
                <div class="row-title">${doc.title}</div>
                <div class="row-meta"><span class="meta-tag">${doc.tag}</span><span>${doc.folder}</span><span>${doc.date}</span></div>
              </div>
            </div>
          `).join('')}
        </div>
      </div>

      <div class="fab-cluster">
        <button class="fab-primary" onclick="App.go('camera')">
          <svg width="18" height="18"><use href="#ic-camera"/></svg>
          Scan to Folder
        </button>
      </div>
      ${this.renderBottomNav('folders')}
    </div>`;
  },

  /* 7. PDF SUITE & SPECIALIZED PRODUCTIVITY WORKBENCH (Tab 3 — Screens 21–28, 46–49) */
  pdfSuite(state) {
    const tool = state.pdfSubTool;
    if (tool) return this.renderPdfSubTool(tool, state);

    return `<div class="screen-root">
      <header class="header">
        <span class="brand-word">PDF Suite</span>
        <span class="meta-tag accent">100% ON-DEVICE</span>
      </header>

      <div class="content" style="padding-top:4px;">
        <div class="section-head"><span class="section-title">PDF Manipulation & Security</span><span class="meta-tag">IMPLEMENTED</span></div>
        <div class="doc-stream">
          <div class="hairline-row" onclick="App.go('pdf-suite', 'merge')">
            <div class="row-left"><div class="row-label-col"><div class="row-h">Merge PDFs</div><div class="row-p">Combine multiple documents into one ordered PDF</div></div></div>
            <span class="meta-tag">MERGE</span>
          </div>
          <div class="hairline-row" onclick="App.go('pdf-suite', 'split')">
            <div class="row-left"><div class="row-label-col"><div class="row-h">Visual Split & Page Extraction</div><div class="row-p">Tap miniature pages or enter ranges (e.g. 1-3, 5)</div></div></div>
            <span class="meta-tag">SPLIT</span>
          </div>
          <div class="hairline-row" onclick="App.go('pdf-suite', 'compress')">
            <div class="row-left"><div class="row-label-col"><div class="row-h">Compress PDF Size</div><div class="row-p">300 / 200 / 150 DPI presets with measured MB savings</div></div></div>
            <span class="meta-tag success">-59%</span>
          </div>
          <div class="hairline-row" onclick="App.go('pdf-suite', 'sign')">
            <div class="row-left"><div class="row-label-col"><div class="row-h">Digital Signature, Stamps & Watermark</div><div class="row-p">Freehand ink pad, CONFIDENTIAL/APPROVED stamps</div></div></div>
            <span class="meta-tag">SIGN</span>
          </div>
          <div class="hairline-row" onclick="App.go('pdf-suite', 'protect')">
            <div class="row-left"><div class="row-label-col"><div class="row-h">AES-256 Password & Permanent Redaction</div><div class="row-p">Encrypt/unlock PDFs & permanently zero raster pixels</div></div></div>
            <span class="meta-tag">AES-256</span>
          </div>
        </div>

        <div class="section-head" style="margin-top:20px;"><span class="section-title">OCR, বাংলা & Document Intelligence</span></div>
        <div class="doc-stream">
          <div class="hairline-row" onclick="App.go('ocr-ai')">
            <div class="row-left"><div class="row-label-col"><div class="row-h">Optical Character Recognition (OCR & বাংলা)</div><div class="row-p">Word bounding boxes, numeral converter, searchable PDF</div></div></div>
            <span class="meta-tag accent">OCR · BN</span>
          </div>
          <div class="hairline-row" onclick="App.setOcrTab('ai'); App.go('ocr-ai')">
            <div class="row-left"><div class="row-label-col"><div class="row-h">Offline AI Executive Summary & Q&A</div><div class="row-p">On-device TextRank digest & passage citations</div></div></div>
            <span class="meta-tag">OFFLINE AI</span>
          </div>
          <div class="hairline-row" onclick="App.setOcrTab('translate'); App.go('ocr-ai')">
            <div class="row-left"><div class="row-label-col"><div class="row-h">Document Translation (English ⇄ বাংলা)</div><div class="row-p">Side-by-side translation reader</div></div></div>
            <span class="meta-tag">EN ⇄ BN</span>
          </div>
        </div>

        <div class="section-head" style="margin-top:20px;"><span class="section-title">Specialized Document Extractors</span></div>
        <div class="doc-stream">
          <div class="hairline-row" onclick="App.go('pdf-suite', 'receipt')">
            <div class="row-left"><div class="row-label-col"><div class="row-h">Receipt & Commercial Invoice Ledger</div><div class="row-p">Subtotal + VAT math check & CSV spreadsheet export</div></div></div>
            <span class="meta-tag success">CSV</span>
          </div>
          <div class="hairline-row" onclick="App.go('pdf-suite', 'card')">
            <div class="row-left"><div class="row-label-col"><div class="row-h">Business Card Contact Folio</div><div class="row-p">Extract Name, Role, Phone, Email → vCard 3.0 (.vcf)</div></div></div>
            <span class="meta-tag">VCARD</span>
          </div>
          <div class="hairline-row" onclick="App.go('pdf-suite', 'countcam')">
            <div class="row-left"><div class="row-label-col"><div class="row-h">CountCam Interactive Pin Counter</div><div class="row-p">Tap-to-pin item counting (TFLite detector planned RISK-09)</div></div></div>
            <span class="meta-tag warning">BETA</span>
          </div>
        </div>
      </div>

      ${this.renderBottomNav('pdf-suite')}
    </div>`;
  },

  renderPdfSubTool(tool, state) {
    const titles = {
      merge: 'Merge PDFs (Screen 21)',
      split: 'Visual Split & Extract (Screen 22)',
      compress: 'Compress PDF (Screen 23)',
      sign: 'Signature & Watermark (Screens 26–27)',
      protect: 'AES-256 & Redaction (Screen 28)',
      receipt: 'Receipt & Invoice Ledger (Screens 46–47)',
      card: 'Business Card Folio (Screen 48)',
      countcam: 'CountCam Pin Counter (Screen 49)'
    };

    return `<div class="screen-root">
      <header class="header" style="border-bottom:1px solid var(--hairline);">
        <div class="brand-lockup">
          <button class="icon-hit" onclick="App.go('pdf-suite', null)"><svg width="20" height="20"><use href="#ic-back"/></svg></button>
          <span class="sub-title">${titles[tool] || 'PDF Workbench'}</span>
        </div>
      </header>

      <div class="content" style="padding-top:12px;">
        ${tool === 'merge' ? `
          <div class="section-head"><span class="section-title">Selected Documents (Drag Order)</span><span class="meta-tag accent">18 PAGES TOTAL</span></div>
          <div class="doc-stream">
            ${this.documents.slice(0, 2).map((d, i) => `
              <div class="stream-row">
                <span class="meta-tag">0${i + 1}</span>
                ${this.renderThumb(d)}
                <div class="row-main"><div class="row-title">${d.title}</div><div class="row-meta"><span>${d.tag}</span><span>${d.size}</span></div></div>
              </div>
            `).join('')}
          </div>
          <div style="margin-top:20px;">
            <div class="section-title" style="margin-bottom:6px;">Output Filename</div>
            <div class="search-bar"><input value="Merged_Legal_And_Deed_2026.pdf" /></div>
            <button class="btn-pill" style="width:100%;margin-top:16px;" onclick="App.toast('Merged 18 pages into Vault'); App.go('viewer')">Merge 2 PDFs into Vault</button>
          </div>
        ` : tool === 'split' ? `
          <div class="section-head"><span class="section-title">Tap Pages to Extract (Commercial Lease · 12P)</span><span class="meta-tag accent">PAGES 1, 2, 4</span></div>
          <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin:10px 0 18px;">
            ${[1,2,3,4,5,6].map(p => {
              const sel = [1,2,4].includes(p);
              return `<div onclick="this.classList.toggle('sel')" style="background:var(--surface);border:${sel ? '2px solid var(--accent)' : '1px solid var(--hairline)'};border-radius:8px;padding:8px;text-align:center;cursor:pointer;">
                <div class="doc-sheet" style="width:100%;height:74px;margin-bottom:6px;"><div class="mini-text-line"></div><div class="mini-text-line" style="width:70%"></div></div>
                <span class="meta-tag ${sel ? 'accent' : ''}">PAGE 0${p} ${sel ? '✓' : ''}</span>
              </div>`;
            }).join('')}
          </div>
          <div class="search-bar"><input value="Range: 1-2, 4 (3 Pages Selected)" /></div>
          <button class="btn-pill" style="width:100%;margin-top:16px;" onclick="App.toast('Extracted 3 pages to new PDF'); App.go('viewer')">Extract 3 Pages to New PDF</button>
        ` : tool === 'compress' ? `
          <div class="folio-card" style="margin-bottom:16px;">
            <div class="folio-info">
              <div class="folio-pill">SOURCE · 2.40 MB (12 PAGES)</div>
              <div class="folio-name">Commercial Lease Agreement.pdf</div>
              <div class="folio-sub" style="margin-bottom:0">Estimated output with Balanced preset: 980 KB (-59%)</div>
            </div>
          </div>
          <div class="doc-stream">
            <div class="hairline-row"><div class="row-left"><div class="row-label-col"><div class="row-h">High Quality (300 DPI · 85% JPEG)</div><div class="row-p">Archival print clarity · Est. 1.75 MB (-27%)</div></div></div><span class="meta-tag">1.75 MB</span></div>
            <div class="hairline-row" style="border-left:3px solid var(--accent);padding-left:10px;"><div class="row-left"><div class="row-label-col"><div class="row-h">Balanced Archive (200 DPI · 65% JPEG)</div><div class="row-p">Recommended for email & sharing · Est. 980 KB (-59%)</div></div></div><span class="meta-tag accent">980 KB ✓</span></div>
            <div class="hairline-row"><div class="row-left"><div class="row-label-col"><div class="row-h">Compact File (150 DPI · 45% JPEG)</div><div class="row-p">Smallest footprint · Est. 520 KB (-78%)</div></div></div><span class="meta-tag">520 KB</span></div>
          </div>
          <button class="btn-pill" style="width:100%;margin-top:18px;" onclick="App.toast('Compressed from 2.40 MB to 980 KB (-59%)'); App.go('viewer')">Compress & Save Copy</button>
        ` : tool === 'sign' ? `
          <div class="section-head"><span class="section-title">Freehand Digital Signature Pad</span><span class="meta-tag">VECTOR INK</span></div>
          <div style="height:140px;background:#FFFFFF;border:1px solid var(--hairline);border-radius:12px;display:flex;flex-direction:column;justify-content:space-between;padding:14px;color:#0052FF;">
            <span style="font-family:var(--font-mono);font-size:9px;color:#94A3B8;">SIGN ABOVE BASELINE</span>
            <div style="font-family:cursive;font-size:28px;text-align:center;color:#0052FF;">Md. Aktaruzzman Emon</div>
            <div style="border-bottom:1px dashed #CBD5E1;"></div>
          </div>
          <div class="hairline-row" style="margin-top:8px;"><div class="row-left"><div class="row-label-col"><div class="row-h">Diagonal Watermark Overlay</div><div class="row-p">CONFIDENTIAL · 25% Opacity · -45° Rotation</div></div></div><div class="toggle on" onclick="this.classList.toggle('on')"></div></div>
          <button class="btn-pill" style="width:100%;margin-top:16px;" onclick="App.toast('Signature & Watermark applied to PDF'); App.go('viewer')">Apply Signature to PDF</button>
        ` : tool === 'protect' ? `
          <div class="section-head"><span class="section-title">AES-256 Encryption & True Redaction</span><span class="meta-tag accent">SECURITY</span></div>
          <div class="search-bar" style="margin-bottom:10px;"><input type="password" value="••••••••••••" placeholder="Enter AES-256 Owner/User Password" /></div>
          <div class="hairline-row"><div class="row-left"><div class="row-label-col"><div class="row-h">Permanent Raster Pixel Redaction</div><div class="row-p">Zeros underlying image pixels (0x000000) & scrubs metadata</div></div></div><span class="meta-tag success">DESTRUCTIVE</span></div>
          <div class="hairline-row"><div class="row-left"><div class="row-label-col"><div class="row-h">Vector Stream Notice (RISK-12)</div><div class="row-p">Flattens vector pages to raster before blackout so no hidden text remains</div></div></div><div class="toggle on"></div></div>
          <button class="btn-pill" style="width:100%;margin-top:16px;" onclick="App.toast('Encrypted with AES-256 & sanitized metadata'); App.go('viewer')">Encrypt & Sanitize PDF</button>
        ` : tool === 'receipt' ? `
          <div class="folio-card" style="margin-bottom:14px;">
            ${this.renderThumb(this.documents[3])}
            <div class="folio-info">
              <div class="folio-pill" style="background:var(--success-soft);color:var(--success);">✓ MATH VERIFIED · SUBTOTAL + VAT = TOTAL</div>
              <div class="folio-name">Square Pharmaceuticals Ltd.</div>
              <div class="folio-sub" style="margin-bottom:0">INV-2026-884 · Nov 12, 2026 · BDT (৳)</div>
            </div>
          </div>
          <div class="doc-stream">
            <div class="hairline-row"><span class="row-h">12× Paracetamol 500mg Box</span><span style="font-family:var(--font-mono)">৳ 2,800.00</span></div>
            <div class="hairline-row"><span class="row-h">05× Seclo 20mg Capsule Strip</span><span style="font-family:var(--font-mono)">৳ 1,400.00</span></div>
            <div class="hairline-row"><span class="row-p">Subtotal</span><span style="font-family:var(--font-mono)">৳ 4,200.00</span></div>
            <div class="hairline-row"><span class="row-p">VAT (15.0%)</span><span style="font-family:var(--font-mono)">৳ 630.00</span></div>
            <div class="hairline-row"><span class="row-h" style="color:var(--accent)">Grand Total</span><strong style="font-family:var(--font-mono);font-size:16px;">৳ 4,830.00</strong></div>
          </div>
          <button class="btn-pill" style="width:100%;margin-top:16px;" onclick="App.toast('Exported INV-2026-884.csv spreadsheet')">Export CSV Ledger</button>
        ` : tool === 'card' ? `
          <div class="folio-card" style="margin-bottom:14px;">
            <div class="folio-info">
              <div class="folio-pill">VCARD 3.0 (.VCF) READY</div>
              <div class="folio-name">Md. Aktaruzzman Emon</div>
              <div class="folio-sub" style="margin-bottom:0">Principal Product Architect · Scaneliq Systems</div>
            </div>
          </div>
          <div class="doc-stream">
            <div class="hairline-row"><span class="row-p">Mobile</span><span class="row-h">+880 1700-000000</span></div>
            <div class="hairline-row"><span class="row-p">Email</span><span class="row-h">emon@scaneliq.app</span></div>
            <div class="hairline-row"><span class="row-p">GitHub</span><span class="row-h">github.com/md-aktaruzzman-emon</span></div>
          </div>
          <button class="btn-pill" style="width:100%;margin-top:16px;" onclick="App.toast('Exported Contact.vcf (vCard 3.0)')">Export vCard (.vcf)</button>
        ` : `
          <div style="padding:8px 10px;background:var(--warning-soft);color:var(--warning);border-radius:8px;font-family:var(--font-mono);font-size:10px;margin-bottom:12px;">
            BETA DISCLOSURE (RISK-09): Interactive pin counter active · Dedicated TFLite object detection model scheduled.
          </div>
          <div class="cam-stage" style="height:240px;margin:0 0 14px;" onclick="App.incCount()">
            <div style="display:grid;grid-template-columns:repeat(4,42px);gap:14px;">
              ${Array.from({ length: state.pinCount || 8 }).map((_, i) => `
                <div style="width:34px;height:34px;border-radius:50%;background:#0052FF;color:#FFF;border:2px solid #FFF;display:flex;align-items:center;justify-content:center;font-family:var(--font-mono);font-size:11px;font-weight:700;">0${i + 1}</div>
              `).join('')}
            </div>
            <div class="cam-pill" style="position:absolute;bottom:10px;">Tap canvas to add pin · Current: ${state.pinCount || 8} items</div>
          </div>
          <div style="display:flex;justify-content:space-between;align-items:center;">
            <button class="btn-pill outline sm" onclick="App.adjCount(-1)">－1 Item</button>
            <strong style="font-family:var(--font-mono);font-size:18px;">${state.pinCount || 8} ITEMS</strong>
            <button class="btn-pill sm" onclick="App.adjCount(1)">＋1 Item</button>
          </div>
        `}
      </div>
    </div>`;
  },

  /* 8. OCR, BENGALI OCR, TRANSLATION & OFFLINE AI (Screens 39–45) */
  ocrAi(state) {
    const tab = state.ocrTab || 'ocr';
    const bnAscii = state.bnAsciiDigits;
    return `<div class="screen-root">
      <header class="header" style="border-bottom:1px solid var(--hairline);">
        <div class="brand-lockup">
          <button class="icon-hit" onclick="App.go('viewer')"><svg width="20" height="20"><use href="#ic-back"/></svg></button>
          <span class="sub-title">OCR & Document Intelligence</span>
        </div>
        <button class="section-action" onclick="App.toast('Copied recognized text to clipboard')">Copy All</button>
      </header>

      <div class="search-zone" style="padding-top:10px;padding-bottom:6px;">
        <div class="scope-tabs">
          <div class="scope-list">
            <button class="scope-tab ${tab === 'ocr' ? 'active' : ''}" onclick="App.setOcrTab('ocr')">OCR Text</button>
            <button class="scope-tab ${tab === 'bangla' ? 'active' : ''}" onclick="App.setOcrTab('bangla')">বাংলা OCR</button>
            <button class="scope-tab ${tab === 'translate' ? 'active' : ''}" onclick="App.setOcrTab('translate')">Translate</button>
            <button class="scope-tab ${tab === 'ai' ? 'active' : ''}" onclick="App.setOcrTab('ai')">AI Brief</button>
          </div>
        </div>
      </div>

      <div class="content">
        ${tab === 'ocr' ? `
          <div class="section-head" style="margin-top:6px;"><span class="section-title">Interactive Bounding Boxes (Tap box)</span><span class="meta-tag accent">LATIN · 99.1%</span></div>
          <div style="background:var(--surface);border:1px solid var(--hairline);border-radius:10px;padding:12px;margin-bottom:14px;font-size:12px;line-height:1.8;">
            <span style="background:var(--accent-soft);border:1px solid var(--accent);padding:2px 5px;border-radius:4px;cursor:pointer;" onclick="App.toast('Selected Box 1: COMMERCIAL LEASE AGREEMENT')">COMMERCIAL LEASE AGREEMENT</span><br>
            <span style="background:var(--surface-subtle);border:1px solid var(--hairline);padding:2px 5px;border-radius:4px;">Clause 8.2: Annual rent of $84,200.00 payable quarterly</span>
          </div>
          <div class="section-head"><span class="section-title">Editable Extracted Text</span><span class="meta-tag">1,420 WORDS</span></div>
          <div style="background:var(--surface);border:1px solid var(--hairline);border-radius:10px;padding:14px;font-size:13px;line-height:1.65;color:var(--text-1);">
            THIS COMMERCIAL LEASE AGREEMENT is entered into on November 18, 2026. Lessee agrees to an annual rent of $84,200.00 payable in four quarterly installments of $21,050.00.
          </div>
          <div style="display:flex;gap:10px;margin-top:14px;">
            <button class="btn-pill outline" style="flex:1" onclick="App.toast('Saved Lease_OCR.txt')">Export .txt</button>
            <button class="btn-pill" style="flex:1" onclick="App.toast('Embedded invisible OCR layer in PDF'); App.go('viewer')">Embed in PDF</button>
          </div>
        ` : tab === 'bangla' ? `
          <div style="padding:9px 11px;background:var(--accent-soft);border:1px solid var(--accent);border-radius:8px;font-size:11px;line-height:1.45;margin:6px 0 12px;">
            <strong>Engineering Status (RISK-03):</strong> Numeral normalization (০-৯ ↔ 0-9) is active. Native offline Tesseract <code>ben.traineddata</code> integration is scheduled to replace the ML Kit Indic fallback.
          </div>
          <div class="hairline-row" onclick="App.toggleBnDigits()">
            <span class="row-h">Normalize Bengali Digits (০-৯ → 0-9)</span>
            <div class="toggle ${bnAscii ? 'on' : ''}"></div>
          </div>
          <div style="background:var(--surface);border:1px solid var(--hairline);border-radius:10px;padding:14px;margin-top:12px;font-size:14px;line-height:1.75;">
            <strong>বাংলা জমির দলিল — খতিয়ান ${bnAscii ? '412' : '৪১২'}</strong><br>
            তফসিল পরিচয়: মৌজা ধানমন্ডি, খতিয়ান নং ${bnAscii ? '412' : '৪১২'}, দাগ নং ${bnAscii ? '1890' : '১৮৯০'}, মোট জমির পরিমাণ ${bnAscii ? '0.1550' : '০.১৫৫০'} একর। বার্ষিক কর পরিশোধিতঃ ৳ ${bnAscii ? '4,830' : '৪,৮৩০'} টাকা মাত্র।
          </div>
        ` : tab === 'translate' ? `
          <div class="section-head" style="margin-top:6px;"><span class="section-title">English ⇄ বাংলা (Bengali)</span><span class="meta-tag warning">ONLINE · GOOGLE TRANSLATE (RISK-10)</span></div>
          <div style="background:var(--surface-subtle);border-radius:10px;padding:12px;font-size:12.5px;color:var(--text-2);margin-bottom:10px;">
            <strong>Source (English):</strong><br>Lessee agrees to an annual rent of $84,200 payable in quarterly installments.
          </div>
          <div style="background:var(--surface);border:1px solid var(--hairline);border-radius:10px;padding:14px;font-size:14px;line-height:1.7;">
            <strong>অনুবাদ (বাংলা):</strong><br>ভাড়াটিয়া ত্রৈমাসিক কিস্তিতে প্রদেয় বার্ষিক $৮৪,২০০ ভাড়া প্রদানে সম্মত হন।
          </div>
        ` : `
          <div class="section-head" style="margin-top:6px;"><span class="section-title">100% Offline Extractive TextRank & TF-IDF</span><span class="meta-tag success">ON-DEVICE</span></div>
          <div class="folio-card" style="margin-bottom:12px;">
            <div class="folio-info">
              <div class="folio-pill">EXECUTIVE SUMMARY · 3 KEY SENTENCES</div>
              <div class="folio-name">Commercial Lease Obligation Brief</div>
              <div class="folio-sub" style="margin-bottom:0;line-height:1.5;">1. Annual rent fixed at $84,200 ($21,050/quarter).<br>2. Term runs 36 months starting Nov 18, 2026.<br>3. 60-day written notice required for renewal.</div>
            </div>
          </div>
          <div class="section-title" style="margin-bottom:6px;">Ask Document (TF-IDF Passage Citation)</div>
          <div class="search-bar" style="margin-bottom:10px;"><input value="What is the annual rent obligation?" /></div>
          <div style="background:var(--surface);border-left:2.5px solid var(--accent);padding:10px 12px;border-radius:0 8px 8px 0;font-size:12.5px;">
            <strong>Answer (94% Match · Page 01):</strong> "Lessee agrees to an annual rent of $84,200 payable in quarterly installments."
          </div>
        `}
      </div>
    </div>`;
  },

  /* 9. SETTINGS, SECURITY VAULT, APP LOCK & BACKUP (Screens 50–65) */
  settings(state) {
    if (state.settingsSub === 'lock') return this.renderAppLock(state);
    if (state.settingsSub === 'backup') return this.renderBackup(state);

    return `<div class="screen-root">
      <header class="header" style="border-bottom:1px solid var(--hairline);">
        <div class="brand-lockup">
          <button class="icon-hit" onclick="App.go('home')"><svg width="20" height="20"><use href="#ic-back"/></svg></button>
          <span class="sub-title">Settings & Vault</span>
        </div>
        <span class="meta-tag">v1.0.0+1</span>
      </header>

      <div class="content">
        <div class="section-head" style="margin-top:10px;"><span class="section-title">Appearance (Screen 61)</span></div>
        <div class="hairline-row" onclick="App.toggleSingleTheme()">
          <div class="row-left"><div class="row-label-col"><div class="row-h">Editorial Theme Mode</div><div class="row-p">Switch between Gallery Alabaster (Light) & Carbon Studio (Dark)</div></div></div>
          <span class="meta-tag accent">SWITCH THEME</span>
        </div>

        <div class="section-head" style="margin-top:18px;"><span class="section-title">Security & Backup (Screens 50–55)</span></div>
        <div class="hairline-row" onclick="App.setSettingsSub('lock')">
          <div class="row-left"><div class="row-label-col"><div class="row-h">App Lock & Biometric Barrier</div><div class="row-p">PBKDF2-HMAC-SHA256 (100k iterations) · Test PIN Keypad</div></div></div>
          <span class="meta-tag success">ACTIVE →</span>
        </div>
        <div class="hairline-row" onclick="App.setSettingsSub('backup')">
          <div class="row-left"><div class="row-label-col"><div class="row-h">Encrypted Backup (.scaneliq) & Sync</div><div class="row-p">AES-256-CBC + HMAC-SHA256 (EtM V2) · Local & Planned Cloud</div></div></div>
          <span class="meta-tag">VAULT →</span>
        </div>
        <div class="hairline-row">
          <div class="row-left"><div class="row-label-col"><div class="row-h">Zero-Account Local Identity (Screen 55)</div><div class="row-p">No mandatory cloud login · Device: Scaneliq Studio</div></div></div>
          <span class="meta-tag">LOCAL-FIRST</span>
        </div>

        <div class="section-head" style="margin-top:18px;"><span class="section-title">Scanner, PDF & Storage (Screens 59, 60, 62, 63)</span></div>
        <div class="hairline-row" onclick="App.openModal('rename')">
          <div class="row-left"><div class="row-label-col"><div class="row-h">Smart Filename Template (Screen 59)</div><div class="row-p">Scan_[Date]_[Category]_[Counter] · Default: Magic Color</div></div></div>
          <span class="meta-tag">EDIT</span>
        </div>
        <div class="hairline-row">
          <div class="row-left"><div class="row-label-col"><div class="row-h">PDF Export Standards (Screen 60)</div><div class="row-p">ISO A4 · 200 DPI Balanced · Unwatermarked Guarantee</div></div></div>
          <span class="meta-tag">ISO A4</span>
        </div>
        <div class="hairline-row" onclick="App.toast('Cleaned 0.6 MB stale temp files · 3 items in 30-day Trash')">
          <div class="row-left"><div class="row-label-col"><div class="row-h">Storage & 30-Day Trash Recovery (Screen 63)</div><div class="row-p">48.6 MB used locally · 3 deleted scans recoverable</div></div></div>
          <span class="meta-tag">48.6 MB</span>
        </div>

        <div class="section-head" style="margin-top:18px;"><span class="section-title">Edition, Help & About (Screens 56, 64, 65)</span></div>
        <div class="hairline-row" onclick="App.openModal('pro')">
          <div class="row-left"><div class="row-label-col"><div class="row-h">Scaneliq Edition & Proposed Pro (Screen 56)</div><div class="row-p">All local features unlocked · View proposed Cloud/AI add-on</div></div></div>
          <span class="meta-tag">PROPOSED</span>
        </div>
        <div class="hairline-row" onclick="App.go('onboarding')">
          <div class="row-left"><div class="row-label-col"><div class="row-h">Preview Onboarding & Splash (Screens 2–3)</div><div class="row-p">Launch 3-slide editorial product walkthrough</div></div></div>
          <span class="meta-tag">LAUNCH →</span>
        </div>
      </div>
    </div>`;
  },

  /* Screen 50 & 51: Full-Screen App Lock & Biometric Keypad */
  renderAppLock(state) {
    const len = (state.pinInput || '').length;
    return `<div class="screen-root" style="justify-content:space-between;padding:28px 24px 36px;text-align:center;">
      <div style="display:flex;justify-content:space-between;align-items:center;">
        <button class="section-action" onclick="App.setSettingsSub(null)">← Settings</button>
        <span class="meta-tag">PBKDF2 · 100K ITERS</span>
      </div>

      <div style="display:flex;flex-direction:column;align-items:center;gap:12px;">
        <div class="brand-glyph" style="width:40px;height:40px;border-radius:10px;"><svg width="22" height="22"><use href="#ic-glyph"/></svg></div>
        <div class="brand-word">Vault Locked</div>
        <div style="font-size:12.5px;color:var(--text-2);">Enter 4-digit security PIN or tap Biometrics</div>
        <div style="display:flex;gap:14px;margin-top:10px;">
          ${[0,1,2,3].map(i => `<div style="width:13px;height:13px;border-radius:50%;border:1.5px solid var(--text-1);background:${i < len ? 'var(--accent)' : 'transparent'}"></div>`).join('')}
        </div>
      </div>

      <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:12px;max-width:280px;margin:0 auto;width:100%;">
        ${[1,2,3,4,5,6,7,8,9].map(n => `
          <button onclick="App.tapPin('${n}')" style="height:54px;border-radius:12px;border:1px solid var(--hairline);background:var(--surface);color:var(--text-1);font-family:var(--font-head);font-size:20px;font-weight:600;cursor:pointer;">${n}</button>
        `).join('')}
        <button onclick="App.toast('Biometric sensor verified · Vault Unlocked'); App.setSettingsSub(null)" title="Biometric Unlock" style="height:54px;border-radius:12px;border:1px solid var(--accent);background:var(--accent-soft);color:var(--accent);font-size:11px;font-weight:700;cursor:pointer;">BIO ✓</button>
        <button onclick="App.tapPin('0')" style="height:54px;border-radius:12px;border:1px solid var(--hairline);background:var(--surface);color:var(--text-1);font-family:var(--font-head);font-size:20px;font-weight:600;cursor:pointer;">0</button>
        <button onclick="App.tapPin('del')" style="height:54px;border-radius:12px;border:1px solid var(--hairline);background:var(--surface);color:var(--text-2);font-size:16px;cursor:pointer;">⌫</button>
      </div>
    </div>`;
  },

  /* Screens 53 & 54: Backup, Restore & Synchronization */
  renderBackup(state) {
    return `<div class="screen-root">
      <header class="header" style="border-bottom:1px solid var(--hairline);">
        <div class="brand-lockup">
          <button class="icon-hit" onclick="App.setSettingsSub(null)"><svg width="20" height="20"><use href="#ic-back"/></svg></button>
          <span class="sub-title">Backup & Sync Vault</span>
        </div>
      </header>

      <div class="content" style="padding-top:12px;">
        <div class="folio-card" style="margin-bottom:16px;">
          <div class="folio-info">
            <div class="folio-pill">SCANELIQ_ENC_V2 · AES-256-CBC + HMAC-SHA256</div>
            <div class="folio-name">42 Documents · 5 Folders (48.6 MB)</div>
            <div class="folio-sub" style="margin-bottom:0">64-byte PBKDF2 Key Separation + Zip-Slip traversal protection</div>
          </div>
        </div>

        <div class="section-head"><span class="section-title">Local Encrypted Archive (Implemented)</span><span class="meta-tag success">VERIFIED</span></div>
        <div class="search-bar" style="margin-bottom:10px;"><input type="password" value="••••••••••••" placeholder="Backup Encryption Passphrase" /></div>
        <div style="display:flex;gap:10px;margin-bottom:20px;">
          <button class="btn-pill" style="flex:1" onclick="App.toast('Created Scaneliq_Backup_20261118.scaneliq (SHA-256 Verified)')">Create .scaneliq</button>
          <button class="btn-pill outline" style="flex:1" onclick="App.toast('Restored 42 documents non-destructively')">Restore Archive</button>
        </div>

        <div class="section-head"><span class="section-title">Multi-Device Sync Status (Screen 54)</span></div>
        <div class="hairline-row" onclick="App.toast('Exported EncryptedSyncEnvelope.json (LWW Timestamped)')">
          <div class="row-left"><div class="row-label-col"><div class="row-h">Local E2EE Sync Envelope (.json)</div><div class="row-p">Last-Write-Wins conflict resolution across devices</div></div></div>
          <span class="meta-tag success">ACTIVE</span>
        </div>
        <div class="hairline-row">
          <div class="row-left"><div class="row-label-col"><div class="row-h">Google Drive AppData & WebDAV Transport</div><div class="row-p">Disclosed per RISK-08: Cloud transport adapter planned</div></div></div>
          <span class="meta-tag warning">PLANNED</span>
        </div>
      </div>
    </div>`;
  },

  /* Screens 2 & 3: Onboarding & Splash Walkthrough */
  onboarding(state) {
    return `<div class="screen-root" style="justify-content:space-between;padding:24px 24px 36px;">
      <div style="display:flex;justify-content:space-between;align-items:center;">
        <div class="brand-lockup">
          <div class="brand-glyph"><svg width="15" height="15"><use href="#ic-glyph"/></svg></div>
          <span class="brand-word" style="font-size:18px;">Scaneliq</span>
        </div>
        <button class="section-action" onclick="App.go('home')">Skip to App →</button>
      </div>

      <div style="display:flex;flex-direction:column;align-items:center;text-align:center;gap:18px;">
        <div class="folio-paper-stack" style="width:110px;height:144px;">
          <div class="paper-back"></div>
          <div class="paper-front" style="padding:12px;">
            <div class="mini-doc-title" style="font-size:7px;">SCANELIQ VAULT</div>
            <div class="mini-text-line" style="width:92%;height:3px;"></div>
            <div class="mini-text-line" style="width:80%;height:3px;"></div>
            <div class="mini-table" style="padding:4px;"><div class="mini-table-row" style="font-size:6px;"><span>AES-256</span><span>LOCAL</span></div></div>
            <div class="mini-sig" style="width:30px;"></div>
          </div>
        </div>
        <div>
          <span class="folio-pill">EDITORIAL GALLERY MINIMAL · CONCEPT A</span>
          <h2 style="font-family:var(--font-head);font-size:23px;font-weight:700;letter-spacing:-0.03em;margin-top:8px;">Studio-Grade Scanning.<br>100% On Your Device.</h2>
          <p style="font-size:13px;color:var(--text-2);line-height:1.55;margin-top:8px;">
            Zero mandatory accounts, zero watermarks, instant perspective warp, searchable English & বাংলা OCR, and AES-256 encrypted local archives.
          </p>
        </div>
      </div>

      <button class="btn-pill" style="width:100%;height:48px;" onclick="App.go('home')">Enter Scaneliq Workspace</button>
    </div>`;
  }
};
