namespace UsbChecker;

partial class Form1
{
    /// <summary>
    ///  Required designer variable.
    /// </summary>
    private System.ComponentModel.IContainer components = null;

    /// <summary>
    ///  Clean up any resources being used.
    /// </summary>
    /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
    protected override void Dispose(bool disposing)
    {
        if (disposing && (components != null))
        {
            components.Dispose();
        }
        base.Dispose(disposing);
    }

    #region Windows Form Designer generated code

    /// <summary>
    ///  Required method for Designer support - do not modify
    ///  the contents of this method with the code editor.
    /// </summary>
    private void InitializeComponent()
    {
        this.components = new System.ComponentModel.Container();
        this.panelCard = new Panel();
        this.lblTitle = new Label();
        this.lblKeysHdr = new Label();
        this.lblKeysValue = new Label();
        this.lblActiveHdr = new Label();
        this.lblActiveValue = new Label();
        this.lblDrivesHdr = new Label();
        this.lblDrivesValue = new Label();
        this.lblUsbHdr = new Label();
        this.lblUsbValue = new Label();
        this.lblResizeGrip = new Label();
        this.panelCard.SuspendLayout();
        this.SuspendLayout();
        // 
        // panelCard
        // 
        this.panelCard.Controls.Add(this.lblUsbValue);
        this.panelCard.Controls.Add(this.lblUsbHdr);
        this.panelCard.Controls.Add(this.lblDrivesValue);
        this.panelCard.Controls.Add(this.lblDrivesHdr);
        this.panelCard.Controls.Add(this.lblActiveValue);
        this.panelCard.Controls.Add(this.lblActiveHdr);
        this.panelCard.Controls.Add(this.lblKeysValue);
        this.panelCard.Controls.Add(this.lblKeysHdr);
        this.panelCard.Controls.Add(this.lblTitle);
        this.panelCard.Controls.Add(this.lblResizeGrip);
        this.panelCard.Dock = DockStyle.Fill;
        this.panelCard.Location = new Point(0, 0);
        this.panelCard.Name = "panelCard";
        this.panelCard.Padding = new Padding(10, 8, 10, 8);
        this.panelCard.Size = new Size(424, 312);
        this.panelCard.TabIndex = 0;
        // 
        // lblTitle
        // 
        this.lblTitle.AutoSize = true;
        this.lblTitle.Font = new Font("Segoe UI", 9F, FontStyle.Bold, GraphicsUnit.Point);
        this.lblTitle.Location = new Point(12, 10);
        this.lblTitle.Name = "lblTitle";
        this.lblTitle.Size = new Size(99, 20);
        this.lblTitle.TabIndex = 0;
        this.lblTitle.Text = "MONITOR SUITE";
        // 
        // lblKeysHdr
        // 
        this.lblKeysHdr.AutoSize = true;
        this.lblKeysHdr.Font = new Font("Segoe UI", 8F, FontStyle.Bold, GraphicsUnit.Point);
        this.lblKeysHdr.Location = new Point(12, 40);
        this.lblKeysHdr.Name = "lblKeysHdr";
        this.lblKeysHdr.Size = new Size(95, 19);
        this.lblKeysHdr.TabIndex = 1;
        this.lblKeysHdr.Text = "KEYS / MOUSE";
        // 
        // lblKeysValue
        // 
        this.lblKeysValue.AutoSize = true;
        this.lblKeysValue.Font = new Font("Consolas", 9F, FontStyle.Regular, GraphicsUnit.Point);
        this.lblKeysValue.Location = new Point(12, 60);
        this.lblKeysValue.Name = "lblKeysValue";
        this.lblKeysValue.Size = new Size(18, 20);
        this.lblKeysValue.TabIndex = 2;
        this.lblKeysValue.Text = "...";
        // 
        // lblActiveHdr
        // 
        this.lblActiveHdr.AutoSize = true;
        this.lblActiveHdr.Font = new Font("Segoe UI", 8F, FontStyle.Bold, GraphicsUnit.Point);
        this.lblActiveHdr.Location = new Point(12, 92);
        this.lblActiveHdr.Name = "lblActiveHdr";
        this.lblActiveHdr.Size = new Size(111, 19);
        this.lblActiveHdr.TabIndex = 3;
        this.lblActiveHdr.Text = "ACTIVE WINDOW";
        // 
        // lblActiveValue
        // 
        this.lblActiveValue.Font = new Font("Consolas", 9F, FontStyle.Regular, GraphicsUnit.Point);
        this.lblActiveValue.Location = new Point(12, 112);
        this.lblActiveValue.Name = "lblActiveValue";
        this.lblActiveValue.Size = new Size(398, 50);
        this.lblActiveValue.TabIndex = 4;
        this.lblActiveValue.Text = "(loading)";
        // 
        // lblDrivesHdr
        // 
        this.lblDrivesHdr.AutoSize = true;
        this.lblDrivesHdr.Font = new Font("Segoe UI", 8F, FontStyle.Bold, GraphicsUnit.Point);
        this.lblDrivesHdr.Location = new Point(12, 168);
        this.lblDrivesHdr.Name = "lblDrivesHdr";
        this.lblDrivesHdr.Size = new Size(51, 19);
        this.lblDrivesHdr.TabIndex = 5;
        this.lblDrivesHdr.Text = "DRIVES";
        // 
        // lblDrivesValue
        // 
        this.lblDrivesValue.Font = new Font("Consolas", 9F, FontStyle.Regular, GraphicsUnit.Point);
        this.lblDrivesValue.Location = new Point(12, 188);
        this.lblDrivesValue.Name = "lblDrivesValue";
        this.lblDrivesValue.Size = new Size(398, 38);
        this.lblDrivesValue.TabIndex = 6;
        this.lblDrivesValue.Text = "(loading)";
        // 
        // lblUsbHdr
        // 
        this.lblUsbHdr.AutoSize = true;
        this.lblUsbHdr.Font = new Font("Segoe UI", 8F, FontStyle.Bold, GraphicsUnit.Point);
        this.lblUsbHdr.Location = new Point(12, 230);
        this.lblUsbHdr.Name = "lblUsbHdr";
        this.lblUsbHdr.Size = new Size(77, 19);
        this.lblUsbHdr.TabIndex = 7;
        this.lblUsbHdr.Text = "USB (LAST)";
        // 
        // lblUsbValue
        // 
        this.lblUsbValue.Font = new Font("Consolas", 9F, FontStyle.Regular, GraphicsUnit.Point);
        this.lblUsbValue.Location = new Point(12, 250);
        this.lblUsbValue.Name = "lblUsbValue";
        this.lblUsbValue.Size = new Size(398, 18);
        this.lblUsbValue.TabIndex = 8;
        this.lblUsbValue.Text = "(waiting)";
        // 
        // lblResizeGrip
        // 
        this.lblResizeGrip.Anchor = AnchorStyles.Bottom | AnchorStyles.Right;
        this.lblResizeGrip.AutoSize = true;
        this.lblResizeGrip.Font = new Font("Consolas", 9F, FontStyle.Regular, GraphicsUnit.Point);
        this.lblResizeGrip.Location = new Point(392, 284);
        this.lblResizeGrip.Name = "lblResizeGrip";
        this.lblResizeGrip.Size = new Size(24, 18);
        this.lblResizeGrip.TabIndex = 9;
        this.lblResizeGrip.Text = "///";
        // 
        // Form1
        // 
        this.AutoScaleMode = AutoScaleMode.Font;
        this.ClientSize = new Size(424, 312);
        this.Controls.Add(this.panelCard);
        this.FormBorderStyle = FormBorderStyle.None;
        this.KeyPreview = true;
        this.MaximizeBox = false;
        this.MinimumSize = new Size(410, 250);
        this.Name = "Form1";
        this.ShowInTaskbar = false;
        this.StartPosition = FormStartPosition.Manual;
        this.Text = "Monitor Suite";
        this.panelCard.ResumeLayout(false);
        this.panelCard.PerformLayout();
        this.ResumeLayout(false);
    }

    #endregion

    private Panel panelCard;
    private Label lblTitle;
    private Label lblKeysHdr;
    private Label lblKeysValue;
    private Label lblActiveHdr;
    private Label lblActiveValue;
    private Label lblDrivesHdr;
    private Label lblDrivesValue;
    private Label lblUsbHdr;
    private Label lblUsbValue;
    private Label lblResizeGrip;
}
