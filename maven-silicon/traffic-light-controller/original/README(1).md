# 🚦 Traffic Light Controller (Highway–Country Road Junction)

This project implements a Finite State Machine (FSM)-based **Traffic Light Controller** in Verilog for managing a road junction between a **Highway** 
and a **Country road**, using real-time vehicle detection via sensor input. The design is simulated and verified using **Xilinx ISE**.



## 📘 Project Description

The traffic controller prioritizes the **Highway** when no vehicle is present on the **Country road**. When a vehicle is detected (via a sensor), 
the FSM transitions through appropriate states to give access to the Country road, following proper RED-GREEN-YELLOW traffic sequences.



## 🧠 Features

- FSM-based control logic
- Sensor input to detect car presence on Country road
- Priority handling for Highway road
- Safe traffic light switching
- Written in synthesizable Verilog
- Simulated and verified in **Xilinx ISE Design Suite**

