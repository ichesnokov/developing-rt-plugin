if `which git cpanm > /dev/null` ; then
    echo "Installing App::revealup"
else
    echo "You need git and cpanm configured, exiting now"
    exit 1;
fi

# Install old version from cpan along with deps
cpanm App::revealup

# Clone repo and install 
git clone https://github.com/yusukebe/App-revealup
cpanm --notest ./App-revealup
