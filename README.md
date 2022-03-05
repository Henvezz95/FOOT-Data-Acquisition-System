# FOOT-Data-Acquisition-System

Bachelor Thesis Project aimed at developing the VHDL part of a Data Acquisition System. The system was designed to be used in the FOOT (FragmentatiOn Of Target) experiment.
The FOOT experiment aims to provide precise nuclear cross-section measurements for two different fields: hadrontherapy and radio-protection space. 

The DAQ System used in the real-life experiments uses this code (with a few incremental updates) to collect and organize data coming from the sensors. 
[More information can be found here](https://arxiv.org/pdf/2010.16251.pdf)

![FOOT](./Images/FOOT.png?raw=true)



# Files
* DAQ System Files: Contains all the VHDL files that describe the functional architecture of the Data Acquisition System
* C_codes: contains the necessary scripts to connect the DE0-Nano to a PC and test the Data Acquisition System
* Images: images with schemes and logos

# Architecture of the Data Acquisition System

All the Entities that make up the Data Acquisition System are contained in the DAQ Module.
![DAQ Module](./Images/DAQ_Module.png?raw=true)
The Event Simulator generates random data in the same format as sensor data. It is used to test the module.
![DAQ on FPGA](./Images/DAQ_on_FPGA.png?raw=true)
The DAQ on FPGA module contains both the DAQ Module and the Event Simulator and can be synthesized on FPGA
