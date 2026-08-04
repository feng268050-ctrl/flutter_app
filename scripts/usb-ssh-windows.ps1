# USB-SSH helpers for Windows host (invoked from Git Bash / MSYS2 via powershell.exe).
# Board gadget: g_ether idVendor=0x2207 idProduct=0x0019 → usually RNDIS on Windows.
param(
	[Parameter(Mandatory = $true)]
	[ValidateSet('list', 'has-ip', 'set-ip', 'ping')]
	[string]$Action,

	[string]$Alias = '',
	[string]$HostAddress = '192.168.55.2',
	[int]$PrefixLength = 24,
	[string]$TargetAddress = '192.168.55.1',
	[string]$Vid = '2207',
	[string]$PidSsh = '0019',
	[string]$PidMtp = '0011'
)

$ErrorActionPreference = 'Stop'

function Get-GadgetNetAdapters {
	$vidRe = "VID_$Vid"
	$pidSshRe = "PID_$PidSsh"
	$pidMtpRe = "PID_$PidMtp"
	$rows = @()

	$adapters = @(Get-NetAdapter -ErrorAction SilentlyContinue)
	foreach ($a in $adapters) {
		$pnp = [string]$a.PnPDeviceID
		if ([string]::IsNullOrWhiteSpace($pnp)) { continue }
		if ($pnp -notmatch $vidRe) { continue }

		$isMtp = $pnp -match $pidMtpRe
		$isSsh = $pnp -match $pidSshRe
		if (-not $isMtp -and -not $isSsh) {
			# Rockchip VID but unexpected PID — still treat non-MTP as SSH candidate.
			if ($pnp -match 'PID_([0-9A-Fa-f]{4})') {
				$pidHex = $Matches[1].ToLowerInvariant()
				if ($pidHex -eq $PidMtp.ToLowerInvariant()) { $isMtp = $true }
				else { $isSsh = $true }
			} else {
				continue
			}
		}

		$serial = '-'
		if ($pnp -match '\\([^\\]+)$') {
			$serial = $Matches[1]
			# Instance IDs sometimes look like "5&..." — keep as LocationID fallback only.
			if ($serial -match '[&]') { $serial = '-' }
		}

		$iface = [string]$a.Name
		if ([string]::IsNullOrWhiteSpace($iface)) { continue }

		$loc = ($pnp -replace '\\', '_')
		if ($isMtp) {
			$usb = ("0x{0}:0x{1}" -f $Vid, $PidMtp)
			# MODE SN ChipID LocationID IFACE IP USB
			$rows += ("USB-MTP`t{0}`t{0}`t{1}`t-`t-`t{2}" -f $serial, $loc, $usb)
		} else {
			$usb = ("0x{0}:0x{1}" -f $Vid, $PidSsh)
			$rows += ("USB-SSH`t{0}`t{0}`t{1}`t{2}`t{3}`t{4}" -f $serial, $loc, $iface, $TargetAddress, $usb)
		}
	}

	# Fallback: Win32_NetworkAdapter when Get-NetAdapter lacks PnPDeviceID (older stacks).
	if ($rows.Count -eq 0) {
		$cim = @(Get-CimInstance -ClassName Win32_NetworkAdapter -ErrorAction SilentlyContinue)
		foreach ($c in $cim) {
			$pnp = [string]$c.PNPDeviceID
			$iface = [string]$c.NetConnectionID
			if ([string]::IsNullOrWhiteSpace($pnp) -or [string]::IsNullOrWhiteSpace($iface)) { continue }
			if ($pnp -notmatch $vidRe) { continue }
			if ($pnp -match $pidMtpRe) { continue }
			if ($pnp -notmatch $pidSshRe -and $pnp -notmatch 'PID_') { continue }

			$serial = '-'
			if ($pnp -match '\\([^\\]+)$' -and $Matches[1] -notmatch '[&]') {
				$serial = $Matches[1]
			}
			$loc = ($pnp -replace '\\', '_')
			$usb = ("0x{0}:0x{1}" -f $Vid, $PidSsh)
			$rows += ("USB-SSH`t{0}`t{0}`t{1}`t{2}`t{3}`t{4}" -f $serial, $loc, $iface, $TargetAddress, $usb)
		}
	}

	return $rows
}

function Test-HostHasIp {
	param([string]$IfAlias, [string]$Ip)
	$addrs = @(Get-NetIPAddress -InterfaceAlias $IfAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue)
	foreach ($a in $addrs) {
		if ($a.IPAddress -eq $Ip) { return $true }
	}
	return $false
}

switch ($Action) {
	'list' {
		Get-GadgetNetAdapters | ForEach-Object { Write-Output $_ }
		exit 0
	}
	'has-ip' {
		if ([string]::IsNullOrWhiteSpace($Alias)) { Write-Error 'Alias required'; exit 2 }
		if (Test-HostHasIp -IfAlias $Alias -Ip $HostAddress) { exit 0 }
		exit 1
	}
	'set-ip' {
		if ([string]::IsNullOrWhiteSpace($Alias)) { Write-Error 'Alias required'; exit 2 }
		if (Test-HostHasIp -IfAlias $Alias -Ip $HostAddress) { exit 0 }
		try {
			# Add host address without forcing a gateway (board must not steal default route).
			New-NetIPAddress -InterfaceAlias $Alias -IPAddress $HostAddress -PrefixLength $PrefixLength -ErrorAction Stop | Out-Null
			exit 0
		} catch {
			# Fallback: netsh (still needs elevation).
			$mask = switch ($PrefixLength) {
				8 { '255.0.0.0' }
				16 { '255.255.0.0' }
				24 { '255.255.255.0' }
				default { '255.255.255.0' }
			}
			$p = Start-Process -FilePath 'netsh.exe' -ArgumentList @(
				'interface', 'ip', 'set', 'address',
				"name=$Alias",
				'source=static',
				"addr=$HostAddress",
				"mask=$mask"
			) -Wait -PassThru -NoNewWindow
			if ($p.ExitCode -eq 0) { exit 0 }
			Write-Error ("Failed to set {0} on '{1}'. Run Git Bash as Administrator, or: make usb-ssh-setup. Detail: {2}" -f $HostAddress, $Alias, $_)
			exit 1
		}
	}
	'ping' {
		# Prefer source-bound ping so we hit the USB link, not Wi-Fi.
		$psi = New-Object System.Diagnostics.ProcessStartInfo
		$psi.FileName = 'ping.exe'
		$psi.Arguments = "-n 1 -w 2000 -S $HostAddress $TargetAddress"
		$psi.RedirectStandardOutput = $true
		$psi.RedirectStandardError = $true
		$psi.UseShellExecute = $false
		$psi.CreateNoWindow = $true
		$p = [System.Diagnostics.Process]::Start($psi)
		$null = $p.StandardOutput.ReadToEnd()
		$null = $p.StandardError.ReadToEnd()
		$p.WaitForExit()
		if ($p.ExitCode -eq 0) { exit 0 }
		# Fallback without -S (some stacks reject source bind).
		$psi.Arguments = "-n 1 -w 2000 $TargetAddress"
		$p2 = [System.Diagnostics.Process]::Start($psi)
		$null = $p2.StandardOutput.ReadToEnd()
		$null = $p2.StandardError.ReadToEnd()
		$p2.WaitForExit()
		exit $p2.ExitCode
	}
}
