// Unity version configuration
// Acecraft uses an older Unity version, not 2022.3.8f1
// Ensure this macro is undefined to use the correct struct layout
#ifdef UNITY_VERSION_2022_3_8F1
#undef UNITY_VERSION_2022_3_8F1
#endif

#define BINARY_NAME "UnityFramework"

#define WAIT_TIME_SEC 60
