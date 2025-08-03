function fish_prompt -d "Write out the prompt"
    printf '%s@%s %s%s%s > ' $USER $hostname \
        (set_color $fish_color_cwd) (prompt_pwd) (set_color normal)
end

if status is-interactive
    set fish_greeting
end

# Enable Starship prompt
starship init fish | source

# QuickShell terminal sequences (only if exists)
if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
end

if test -z "$DISPLAY" -a (tty) = "/dev/tty1"
  exec Hyprland
end


# Aliases
alias pamcan pacman
alias ls 'eza --icons'
alias clear "printf '\033[2J\033[3J\033[1;1H'"

alias q 'qs -c ii'
alias yt 'yt-dlp'
alias gl 'gallery-dl'
alias ai 'tgpt'

# Lenovo Conservation Mode
alias con 'sudo sh -c "echo 1 > /sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode"'
alias coff 'sudo sh -c "echo 0 > /sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode"'
alias checkc 'cat /sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode'

# Power governor check
alias checkp 'cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor'

# System controls
alias bon 'sudo systemctl restart bluetooth.service'
alias bc 'bluetoothctl connect 41:42:E8:67:6B:66'
alias mon 'sudo systemctl enable mysqld'
alias moff 'sudo systemctl disable mysqld'

# Quick config edit
alias execs 'nano ~/.config/hypr/hyprland/execs.conf'
alias keybinds 'nano ~/.config/hypr/hyprland/keybinds.conf'
alias general 'nano ~/.config/hypr/hyprland/general.conf'
alias env 'nano ~/.config/hypr/hyprland/env.conf'
alias colors 'nano ~/.config/hypr/hyprland/colors.conf'
alias rules 'nano ~/.config/hypr/hyprland/rules.conf'

alias conf 'nano .config//fish/config.fish'


set -Ux GTK_THEME Materia-dark

