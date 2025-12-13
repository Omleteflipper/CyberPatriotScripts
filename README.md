**CyberPatriot Scripts & Resources**

Monkies Scripts and resources for CyberPatriot XVIII Season.  
Contains Linux, Windows, and Server hardening scripts, along with supporting documentation.

**Documentation**

[CYBERPATRIOT VULNERABILITY CATEGORY SUMMARY](https://docs.google.com/document/d/1VDKEa_9s1NkpVV9j02kEiZ0ER2IrWVrFk-nO6FYYhUY/edit?usp=sharing)<br>
[PRACTICE IMAGES FOR TESTING](https://docs.google.com/spreadsheets/d/1cdVHtk4w5JDJCYy-EO2_ycr0ZqMgUyjFOVDn5Y8eGVw/edit?gid=0#gid=0)

**Repository Structure**

- Linux/ → Security and hardening scripts for Linux systems  
- Windows/ → Security and hardening scripts for Windows systems  
- Server/ → Scripts and configs for server environments  
- README.md → Project overview and documentation links  

**Notes**

General:  
- Review scripts before running on competition images.  

Linux:  
- GRUB/kernel changes and IDS configs may require manual confirmation to avoid breaking system boot or network functionality.  
- Backups are created automatically in ./backups/ for safety.

**Usage (Linux)**

Run the orchestrator script:

```bash
chmod +x runme.sh
sudo ./runme.sh
