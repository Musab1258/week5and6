## Structs, Arrays and Mappings

### **1. Where are your structs, mappings and arrays stored?**

* **Structs:** Structs can be stored in storage, memory or call data.
* **Arrays:** Arrays can be stored in storage, memory or call data.
* **Mappings:** Mappings can only exist in storage.

### **2. How they behave when executed or called.**

* **Structs and Arrays:** When Structs and Arrays are called/declared their behaviour depends on whether they were stored in storage, memory or call data. 
   
    * **Storage:** When Structs and Arrays are stored in storage, they behave as a reference when called. 
    * **Memory:** When Structs and Arrays are stored in memory, they behave as a copy when called. 
    * **Call Data:** When Structs and Arrays are stored in call data, they behave as a copy when called. 

* **Mappings:** Mappings can only exist in storage and they behave as a reference when called.

### **3. Why don't you need to specify memory or storage with mappings?

You can only declare mappings in storage, so you don't need to specify memory or storage with mappings.
