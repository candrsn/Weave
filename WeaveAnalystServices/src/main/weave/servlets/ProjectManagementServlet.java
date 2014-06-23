package weave.servlets;

import static weave.config.WeaveConfig.initWeaveConfig;

import java.rmi.RemoteException;
import java.sql.SQLException;
import java.util.Map;

import javax.servlet.ServletConfig;
import javax.servlet.ServletException;

import weave.servlets.WeaveServlet;

import weave.config.WeaveContextParams;
import weave.interfaces.IScriptEngine;
import weave.models.AwsProjectService;

public class ProjectManagementServlet extends WeaveServlet implements
		IScriptEngine {
	private static final long serialVersionUID = 1L;

	public ProjectManagementServlet() {

	}

	public void init(ServletConfig config) throws ServletException {
		super.init(config);
		initWeaveConfig(WeaveContextParams.getInstance(config
				.getServletContext()));
	}

	public Object getProjectListFromDatabase(){
		Object returnStatus = null;
		try {
			returnStatus = AwsProjectService.getProjectListFromDatabase();
		} catch (RemoteException e) {
			e.printStackTrace();
		} catch (SQLException e) {
			e.printStackTrace();
		}
		
		return returnStatus;
	}
		
	public Object getQueryObjectsFromDatabase(Map<String, Object> params){
		Object returnStatus = null;
		try {
			returnStatus = AwsProjectService
					.getQueryObjectsFromDatabase(params);
		} catch (RemoteException e) {
			e.printStackTrace();
		} catch (SQLException e) {
			e.printStackTrace();
		}
		
		return returnStatus;
	}

	public Object deleteProjectFromDatabase(Map<String, Object> params){
		Object returnStatus = null;
		try {
			returnStatus = AwsProjectService
					.deleteProjectFromDatabase(params);
		} catch (RemoteException e) {
			e.printStackTrace();
		} catch (SQLException e) {
			e.printStackTrace();
		}
	
		return returnStatus;
	}
	
   public Object deleteQueryObjectFromProjectFromDatabase(Map<String, Object> params) {	
		Object returnStatus = null;	
		try {
			returnStatus = AwsProjectService
					.deleteQueryObjectFromProjectFromDatabase(params);
		} catch (RemoteException e) {
			e.printStackTrace();
		} catch (SQLException e) {
			e.printStackTrace();
		}
	 return returnStatus;	
   }
   
   public Object insertMultipleQueryObjectInProjectFromDatabase(Map<String, Object> params){
	   Object returnStatus = null;
		try {
			returnStatus = AwsProjectService
					.insertMultipleQueryObjectInProjectFromDatabase(params);
		} catch (RemoteException e) {
			e.printStackTrace();
		} catch (SQLException e) {
			e.printStackTrace();
		}
	
		return returnStatus;
	}
   
   public Object getListOfQueryObjectVisualizations(String projectName){
	   Object returnStatus = null;
	   
	   try{
		   returnStatus = AwsProjectService.getListOfQueryObjectVisualizations(projectName);
	   }catch (RemoteException e) {
			e.printStackTrace();
		} catch (SQLException e) {
			e.printStackTrace();
		}
	   
	   return returnStatus;
	   
   }

}
