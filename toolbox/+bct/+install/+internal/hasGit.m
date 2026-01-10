function available = hasGit()
%HASGIT Check if Git is available on system

[status, ~] = system('git --version');
available = (status == 0);

end
