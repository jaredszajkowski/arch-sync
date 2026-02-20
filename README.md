# arch-sync

## Description

This is a template repository for syncing Arch Linux packages and configurations across multiple machines. It includes a script to automate the installation and removal of packages and the synchronization of configuration files.

## Requirements

There is a short list of requirements for using this repository:

* Arch Linux installed on your machines.
* `git` installed to clone the repository and pull/push changes.
* `yay` installed for managing AUR (Arch User Repository) packages.

I personally use `yay` for *most* of my AUR package management, but you can modify the script to use your preferred AUR helper if needed.

## Installation

You can use this repository as a starting point for your own Arch Linux setup. Simply clone the repository, customize the package lists and configuration files to your liking, and run the `arch-sync.sh` script to apply the changes to your system.

## Usage

1. Fork the repository to your own GitLab account.

2. Clone the repository:

```bash
$ git clone https://gitlab.com/username/arch-sync.git
```

3. Edit the configuration files to include the packages and configurations you want to manage, including `packages-install.txt`, `packages-aur-install.txt`, `packages-remove.txt`, `directories-remove.txt`, and `mirrorlist`.

4. Run the synchronization script:

```bash
$ cd arch-sync
$ chmod +x arch-sync.sh
$ ./arch-sync.sh
```

The script will read the package lists and configuration files, install or remove packages as needed, and synchronize your configuration. If the package lists or configuration files have changed since the last run, it will apply the necessary changes to your system. If there are no changes or the changes have already been applied, it will simply exit without making any modifications.

5. Commit and push your changes to your forked repository:

```bash
$ git add .
$ git commit -m "Update package lists and configurations"
$ git push
```

## Configuration Files

* `packages-install.txt`: A list of packages to be installed using `pacman`.
* `packages-aur-install.txt`: A list of AUR packages to be installed using `yay`.
* `packages-remove.txt`: A list of packages to be removed.
* `directories-remove.txt`: A list of directories and files to be removed.
* `mirrorlist`: Custom mirrorlist for pacman.

Each of these files can be edited to include the packages (1 package per line) and Arch Linux configuration files you want to manage across your machines.

<!-- ## Integrate with your tools

* [Set up project integrations](https://gitlab.com/jaredszajkowski/arch-sync/-/settings/integrations) -->

<!-- ## Collaborate with your team

* [Invite team members and collaborators](https://docs.gitlab.com/ee/user/project/members/)
* [Create a new merge request](https://docs.gitlab.com/ee/user/project/merge_requests/creating_merge_requests.html)
* [Automatically close issues from merge requests](https://docs.gitlab.com/ee/user/project/issues/managing_issues.html#closing-issues-automatically)
* [Enable merge request approvals](https://docs.gitlab.com/ee/user/project/merge_requests/approvals/)
* [Set auto-merge](https://docs.gitlab.com/user/project/merge_requests/auto_merge/) -->

<!-- ## Test and Deploy

Use the built-in continuous integration in GitLab.

* [Get started with GitLab CI/CD](https://docs.gitlab.com/ee/ci/quick_start/)
* [Analyze your code for known vulnerabilities with Static Application Security Testing (SAST)](https://docs.gitlab.com/ee/user/application_security/sast/)
* [Deploy to Kubernetes, Amazon EC2, or Amazon ECS using Auto Deploy](https://docs.gitlab.com/ee/topics/autodevops/requirements.html)
* [Use pull-based deployments for improved Kubernetes management](https://docs.gitlab.com/ee/user/clusters/agent/)
* [Set up protected environments](https://docs.gitlab.com/ee/ci/environments/protected_environments.html)

*** -->

<!-- # Editing this README

When you're ready to make this README your own, just edit this file and use the handy template below (or feel free to structure it however you want - this is just a starting point!). Thanks to [makeareadme.com](https://www.makeareadme.com/) for this template. -->

<!-- ## Suggestions for a good README

Every project is different, so consider which of these sections apply to yours. The sections used in the template are suggestions for most open source projects. Also keep in mind that while a README can be too long and detailed, too long is better than too short. If you think your README is too long, consider utilizing another form of documentation rather than cutting out information. -->

<!-- ## Badges
On some READMEs, you may see small images that convey metadata, such as whether or not all the tests are passing for the project. You can use Shields to add some to your README. Many services also have instructions for adding a badge. -->

<!-- ## Visuals
Depending on what you are making, it can be a good idea to include screenshots or even a video (you'll frequently see GIFs rather than actual videos). Tools like ttygif can help, but check out Asciinema for a more sophisticated method. -->

<!-- ## Support
Tell people where they can go to for help. It can be any combination of an issue tracker, a chat room, an email address, etc. -->

<!-- ## Roadmap
If you have ideas for releases in the future, it is a good idea to list them in the README. -->

<!-- ## Contributing
State if you are open to contributions and what your requirements are for accepting them.

For people who want to make changes to your project, it's helpful to have some documentation on how to get started. Perhaps there is a script that they should run or some environment variables that they need to set. Make these steps explicit. These instructions could also be useful to your future self.

You can also document commands to lint the code or run tests. These steps help to ensure high code quality and reduce the likelihood that the changes inadvertently break something. Having instructions for running tests is especially helpful if it requires external setup, such as starting a Selenium server for testing in a browser. -->

<!-- ## Authors and acknowledgment

Show your appreciation to those who have contributed to the project. -->

## License

Licensed under the MIT License. See LICENSE for more information.

## Project status

This project is under periodic active development. It is not yet ready for production use, but it is being used on my personal machines and I am happy to share it with others who may find it useful. I welcome contributions and suggestions for improvement.
