# FPGA-Design-Bomberman-Game



This repository showcases my work on a Bomberman game designed for a Field-Programmable Gate Array (FPGA). This project was undertaken as a graduate-level lab, with the challenge of building a complete game system from foundational elements. The target hardware is the Basys 3 development board.

## Project Overview

The project started with some boilerplate code and provided sprites, along with skeleton files that guided the required module implementations. My core task was to bring the game to life by designing and implementing all game modules and logic, including:

- **Finite State Machines (FSMs):** Designing and implementing various states and transitions for game entities and overall flow.
- **Initiation Logic:** Handling setup and initialization of the game environment.
- **Game Logic:** Developing core gameplay mechanics such as player movement, bomb placement, explosions, and enemy AI.
- **Power-up Logic:** Integrating functionality for various in-game power-ups and their effects.
- **VGA Driver:** Managing display output.
- **Clock Dividers:** Generating pixel clock and controlling 7-segment display timing.

## Technologies Used

- **Hardware Description Language:** Verilog (entire project source code).
- **FPGA Toolchain:** Xilinx Vivado Design Suite for implementation and synthesis.
- **Target Platform:** Basys 3 FPGA Development Board (Artix-7).
