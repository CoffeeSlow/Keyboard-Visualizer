using System.Diagnostics;
using System.Management;
using System.Runtime.InteropServices;
using System.Text;

namespace UsbChecker;

public partial class Form1 : Form
{
    private const int ResizeBorderSize = 8;
    private const int WM_NCHITTEST = 0x84;
    private const int HTCLIENT = 1;
    private const int HTLEFT = 10;
    private const int HTRIGHT = 11;
    private const int HTTOP = 12;
    private const int HTTOPLEFT = 13;
    private const int HTTOPRIGHT = 14;
    private const int HTBOTTOM = 15;
    private const int HTBOTTOMLEFT = 16;
    private const int HTBOTTOMRIGHT = 17;

    private readonly System.Windows.Forms.Timer _uiTimer;
    private readonly System.Windows.Forms.Timer _driveTimer;
    private readonly System.Windows.Forms.Timer _idleTimer;

    private ActiveWindowSnapshot? _lastActive;
    private DateTime _lastActiveStart = DateTime.UtcNow;
    private string _lastActiveStartLocal = DateTime.Now.ToString("HH:mm:ss");

    private ManagementEventWatcher? _usbAddWatcher;
    private ManagementEventWatcher? _usbRemoveWatcher;
    private string _lastUsbLine = "(waiting)";

    public Form1()
    {
        InitializeComponent();

        ApplyTheme();

        // Borderless usability:
        // - Drag anywhere on the card to move
        // - Esc to close
        panelCard.MouseDown += (_, e) =>
        {
            if (e.Button == MouseButtons.Left) WindowDrag.BeginDrag(this);
        };
        MouseDown += (_, e) =>
        {
            if (e.Button == MouseButtons.Left) WindowDrag.BeginDrag(this);
        };
        KeyDown += (_, e) =>
        {
            if (e.KeyCode == Keys.Escape) Close();
        };
        lblResizeGrip.MouseDown += (_, e) =>
        {
            if (e.Button == MouseButtons.Left) WindowDrag.BeginResizeBottomRight(this);
        };
        Resize += (_, _) => ApplyCompactVisibility();

        _uiTimer = new System.Windows.Forms.Timer { Interval = 250 };
        _uiTimer.Tick += (_, _) => RefreshActiveWindow();

        _driveTimer = new System.Windows.Forms.Timer { Interval = 3000 };
        _driveTimer.Tick += (_, _) => RefreshDrives();

        _idleTimer = new System.Windows.Forms.Timer { Interval = 500 };
        _idleTimer.Tick += (_, _) => RefreshIdle();

        Shown += (_, _) =>
        {
            RefreshDrives();
            RefreshActiveWindow(force: true);
            RefreshIdle();
            lblUsbValue.Text = _lastUsbLine;
            ApplyCompactVisibility();
            StartUsbWatchers();
            _uiTimer.Start();
            _driveTimer.Start();
            _idleTimer.Start();
        };

        FormClosing += (_, _) => StopUsbWatchers();
    }

    protected override void WndProc(ref Message m)
    {
        if (m.Msg == WM_NCHITTEST)
        {
            base.WndProc(ref m);
            if ((int)m.Result == HTCLIENT)
            {
                var screenPos = new Point(
                    unchecked((short)(long)m.LParam),
                    unchecked((short)((long)m.LParam >> 16)));
                var clientPos = PointToClient(screenPos);
                var onLeft = clientPos.X <= ResizeBorderSize;
                var onRight = clientPos.X >= ClientSize.Width - ResizeBorderSize;
                var onTop = clientPos.Y <= ResizeBorderSize;
                var onBottom = clientPos.Y >= ClientSize.Height - ResizeBorderSize;

                if (onLeft && onTop) { m.Result = (IntPtr)HTTOPLEFT; return; }
                if (onRight && onTop) { m.Result = (IntPtr)HTTOPRIGHT; return; }
                if (onLeft && onBottom) { m.Result = (IntPtr)HTBOTTOMLEFT; return; }
                if (onRight && onBottom) { m.Result = (IntPtr)HTBOTTOMRIGHT; return; }
                if (onLeft) { m.Result = (IntPtr)HTLEFT; return; }
                if (onRight) { m.Result = (IntPtr)HTRIGHT; return; }
                if (onTop) { m.Result = (IntPtr)HTTOP; return; }
                if (onBottom) { m.Result = (IntPtr)HTBOTTOM; return; }
            }
            return;
        }

        base.WndProc(ref m);
    }

    private void ApplyTheme()
    {
        var windowBg = Color.FromArgb(15, 15, 15);
        var cardBg = Color.FromArgb(15, 15, 15);
        var fg = Color.FromArgb(210, 210, 210);
        var muted = Color.FromArgb(150, 150, 150);
        var accent = Color.FromArgb(255, 184, 0);
        var keyCyan = Color.FromArgb(0, 220, 170);

        BackColor = windowBg;
        ForeColor = fg;
        Opacity = 0.88;
        TopMost = true;

        panelCard.BackColor = cardBg;
        panelCard.ForeColor = fg;

        lblTitle.ForeColor = muted;
        lblKeysHdr.ForeColor = muted;
        lblActiveHdr.ForeColor = muted;
        lblDrivesHdr.ForeColor = muted;
        lblUsbHdr.ForeColor = muted;

        lblKeysValue.ForeColor = fg;
        lblActiveValue.ForeColor = fg;
        lblDrivesValue.ForeColor = Color.MediumPurple;
        lblUsbValue.ForeColor = muted;
        lblResizeGrip.ForeColor = muted;
        lblResizeGrip.Cursor = Cursors.SizeNWSE;

        // Make the "arrow" feel like the screenshot.
        if (lblKeysValue.Text.StartsWith("->", StringComparison.Ordinal))
        {
            lblKeysValue.ForeColor = keyCyan;
        }
    }

    private void RefreshActiveWindow(bool force = false)
    {
        var cur = ActiveWindowSnapshot.TryGet();
        if (cur is null)
        {
            lblActiveValue.Text = "No active window";
            return;
        }

        if (!force && _lastActive is not null && _lastActive.Equals(cur))
        {
            var ongoing = DateTime.UtcNow - _lastActiveStart;
            lblActiveValue.Text = $"\"{_lastActive.Title}\"\r\n{_lastActive.ProcessName}.exe (PID {_lastActive.Pid})\r\nDuration: {FormatDuration(ongoing)}";
            return;
        }

        _lastActive = cur;
        _lastActiveStart = DateTime.UtcNow;
        _lastActiveStartLocal = DateTime.Now.ToString("HH:mm:ss");

        var title = string.IsNullOrWhiteSpace(cur.Title) ? "(No title)" : cur.Title.Trim();
        lblActiveValue.Text = $"{title}\r\n{cur.ProcessName}.exe (PID: {cur.Pid})";
    }

    private void RefreshIdle()
    {
        var idle = IdleTime.TryGetSeconds();
        if (idle is null)
        {
            lblKeysValue.Text = "-> Idle: ?";
            lblKeysValue.ForeColor = Color.Yellow;
            return;
        }

        var seconds = idle.Value;
        var active = seconds < 3;
        lblKeysValue.Text = active ? "-> Active" : $"-> Idle: {seconds:0}s";
        lblKeysValue.ForeColor = active ? Color.LimeGreen : Color.Yellow;
    }

    private void ApplyCompactVisibility()
    {
        // Auto-hide lower sections progressively as height shrinks.
        var showUsb = ClientSize.Height >= 300;
        var showDrives = ClientSize.Height >= 250;

        lblDrivesHdr.Visible = showDrives;
        lblDrivesValue.Visible = showDrives;
        lblUsbHdr.Visible = showUsb;
        lblUsbValue.Visible = showUsb;
    }

    private void RefreshDrives()
    {
        try
        {
            var drives = DriveInfo.GetDrives()
                .OrderBy(d => d.Name, StringComparer.OrdinalIgnoreCase)
                .ToList();

            var ts = DateTime.Now.ToString("HH:mm:ss");
            var lines = new List<string>();
            int maxLines = 2;

            foreach (var d in drives)
            {
                if (!d.IsReady) continue;
                var letter = d.Name.TrimEnd('\\');
                var kind = d.DriveType switch
                {
                    DriveType.Fixed => "HDD",
                    DriveType.Removable => "USB",
                    DriveType.Network => "NET",
                    DriveType.CDRom => "CD",
                    _ => d.DriveType.ToString().ToUpperInvariant()
                };
                var vol = string.IsNullOrWhiteSpace(d.VolumeLabel) ? "(no label)" : d.VolumeLabel.Trim();
                var sizeGb = (long)Math.Round(d.TotalSize / (1024d * 1024d * 1024d));
                lines.Add($"[{ts}] {letter}: [{kind}] {vol} {sizeGb}GB");
                if (lines.Count >= maxLines) break;
            }

            lblDrivesHdr.Text = "DRIVES (refreshes every 3s)";
            lblDrivesValue.Text = lines.Count == 0 ? $"[{ts}] (no ready drives)" : string.Join("\r\n", lines);
        }
        catch (Exception ex)
        {
            lblDrivesValue.Text = $"Drive refresh error: {ex.Message}";
        }
    }

    private void StartUsbWatchers()
    {
        StopUsbWatchers();

        // Covers most USB devices (HID, storage, hubs, etc.)
        // Filter keeps noise down vs all PnP changes.
        const string within = "WITHIN 1";
        const string where = "WHERE TargetInstance ISA 'Win32_PnPEntity' AND TargetInstance.PNPDeviceID LIKE 'USB\\\\%'";

        var addQuery = new WqlEventQuery($"SELECT * FROM __InstanceCreationEvent {within} {where}");
        var removeQuery = new WqlEventQuery($"SELECT * FROM __InstanceDeletionEvent {within} {where}");

        _usbAddWatcher = new ManagementEventWatcher(addQuery);
        _usbRemoveWatcher = new ManagementEventWatcher(removeQuery);

        _usbAddWatcher.EventArrived += (_, e) => OnUsbEvent("+", e);
        _usbRemoveWatcher.EventArrived += (_, e) => OnUsbEvent("-", e);

        _usbAddWatcher.Start();
        _usbRemoveWatcher.Start();
    }

    private void StopUsbWatchers()
    {
        void StopOne(ref ManagementEventWatcher? w)
        {
            if (w is null) return;
            try { w.Stop(); } catch { /* ignore */ }
            try { w.Dispose(); } catch { /* ignore */ }
            w = null;
        }

        StopOne(ref _usbAddWatcher);
        StopOne(ref _usbRemoveWatcher);
    }

    private void OnUsbEvent(string kind, EventArrivedEventArgs e)
    {
        try
        {
            var target = (ManagementBaseObject)e.NewEvent["TargetInstance"];
            var name = target["Name"]?.ToString() ?? "(unknown)";
            var cls = target["PNPClass"]?.ToString() ?? "";
            var id = target["PNPDeviceID"]?.ToString() ?? "";

            BeginInvoke(() =>
            {
                var ts = DateTime.Now.ToString("HH:mm:ss");
                // Keep it one line and compact like your screenshot.
                _lastUsbLine = $"[{ts}] {kind} {name}";
                lblUsbValue.Text = _lastUsbLine;
                lblUsbValue.ForeColor = kind == "+" ? Color.Red : Color.FromArgb(160, 160, 160);
            });
        }
        catch
        {
            // ignore malformed events
        }
    }

    private static string FormatGiB(long bytes)
    {
        var gib = bytes / 1024d / 1024d / 1024d;
        return $"{gib:0.0} GiB";
    }

    private static string FormatDuration(TimeSpan d)
    {
        if (d.TotalHours >= 1) return d.ToString(@"hh\:mm\:ss");
        return d.ToString(@"mm\:ss");
    }

    private sealed record ActiveWindowSnapshot(IntPtr Handle, int Pid, string ProcessName, string Title)
    {
        [DllImport("user32.dll")]
        private static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);

        [DllImport("user32.dll")]
        private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

        public static ActiveWindowSnapshot? TryGet()
        {
            var h = GetForegroundWindow();
            if (h == IntPtr.Zero) return null;

            var sb = new StringBuilder(1024);
            GetWindowText(h, sb, sb.Capacity);

            GetWindowThreadProcessId(h, out var pidU);
            var pid = unchecked((int)pidU);

            string procName;
            try
            {
                procName = pid != 0 ? Process.GetProcessById(pid).ProcessName : "unknown";
            }
            catch
            {
                procName = $"pid:{pid}";
            }

            return new ActiveWindowSnapshot(h, pid, procName, sb.ToString());
        }
    }
}

internal static class ControlExtensions
{
    public static void DoubleBuffered(this Control control, bool enabled)
    {
        var prop = typeof(Control).GetProperty("DoubleBuffered", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        prop?.SetValue(control, enabled, null);
    }
}

internal static class IdleTime
{
    [StructLayout(LayoutKind.Sequential)]
    private struct LASTINPUTINFO
    {
        public uint cbSize;
        public uint dwTime;
    }

    [DllImport("user32.dll")]
    private static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

    [DllImport("kernel32.dll")]
    private static extern uint GetTickCount();

    public static double? TryGetSeconds()
    {
        var lii = new LASTINPUTINFO { cbSize = (uint)Marshal.SizeOf<LASTINPUTINFO>() };
        if (!GetLastInputInfo(ref lii)) return null;
        var idleMs = unchecked((long)GetTickCount()) - lii.dwTime;
        if (idleMs < 0) idleMs = 0;
        return idleMs / 1000d;
    }
}

internal static class WindowDrag
{
    private const int WM_NCLBUTTONDOWN = 0xA1;
    private const int HTCAPTION = 0x2;
    private const int HTBOTTOMRIGHT = 17;

    [DllImport("user32.dll")]
    private static extern bool ReleaseCapture();

    [DllImport("user32.dll")]
    private static extern IntPtr SendMessage(IntPtr hWnd, int msg, int wParam, int lParam);

    public static void BeginDrag(Form form)
    {
        try
        {
            ReleaseCapture();
            SendMessage(form.Handle, WM_NCLBUTTONDOWN, HTCAPTION, 0);
        }
        catch
        {
            // ignore
        }
    }

    public static void BeginResizeBottomRight(Form form)
    {
        try
        {
            ReleaseCapture();
            SendMessage(form.Handle, WM_NCLBUTTONDOWN, HTBOTTOMRIGHT, 0);
        }
        catch
        {
            // ignore
        }
    }
}
